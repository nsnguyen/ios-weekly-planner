import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class StickyOrchestratorTests: XCTestCase {
    private var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
    }

    override func tearDown() async throws {
        container = nil
        try await super.tearDown()
    }

    private func makeInsight(kind: InsightKind, text: String) -> AIInsight {
        AIInsight(dayKey: "0:5",
                  text: text,
                  colorHex: kind.colorHex,
                  tiltDegrees: 0,
                  kind: kind,
                  priority: kind.defaultPriority)
    }

    private func ctx(now: Date = Date()) -> DayContext {
        DayContext(weekOffset: 0, dayIdx: 5,
                   events: [], inbox: [],
                   now: now, appleIntelligenceEnabled: true)
    }

    func testCascadeOrder_sortsByPriority() async throws {
        let orch = StickyOrchestrator(generators: [
            FixedGenerator(kind: .inbox, output: makeInsight(kind: .inbox, text: "I")),
            FixedGenerator(kind: .travel, output: makeInsight(kind: .travel, text: "T")),
            FixedGenerator(kind: .keyword, output: makeInsight(kind: .keyword, text: "K")),
        ], fallback: FixedGenerator(kind: .encouragement, output: nil))

        await orch.run(for: ctx(), into: container.mainContext)
        let all = try container.mainContext.fetch(
            FetchDescriptor<AIInsight>(sortBy: [SortDescriptor(\.priority, order: .forward)]))
        XCTAssertEqual(all.map { $0.kind }, [.travel, .keyword, .inbox])
    }

    func testCapAt3_dropsLowestPriority() async throws {
        let orch = StickyOrchestrator(generators: [
            FixedGenerator(kind: .travel, output: makeInsight(kind: .travel, text: "T")),
            FixedGenerator(kind: .weather, output: makeInsight(kind: .weather, text: "W")),
            FixedGenerator(kind: .keyword, output: makeInsight(kind: .keyword, text: "K")),
            FixedGenerator(kind: .inbox, output: makeInsight(kind: .inbox, text: "I")),
        ], fallback: FixedGenerator(kind: .encouragement, output: nil))

        await orch.run(for: ctx(), into: container.mainContext)
        let all = try container.mainContext.fetch(FetchDescriptor<AIInsight>())
        XCTAssertEqual(all.count, 3, "Cap at 3 — inbox should be dropped")
        XCTAssertFalse(all.contains { $0.kind == .inbox })
    }

    func testFallbackToEncouragementWhenPrimaryEmpty() async throws {
        let orch = StickyOrchestrator(generators: [
            FixedGenerator(kind: .travel, output: nil),
            FixedGenerator(kind: .weather, output: nil),
        ], fallback: FixedGenerator(kind: .encouragement,
                                     output: makeInsight(kind: .encouragement, text: "E")))

        await orch.run(for: ctx(), into: container.mainContext)
        let all = try container.mainContext.fetch(FetchDescriptor<AIInsight>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.kind, .encouragement)
    }

    func testTTLCacheSkipsSecondCallWithinWindow() async {
        let recorder = CountingGenerator(kind: .travel)
        let orch = StickyOrchestrator(generators: [recorder],
                                       fallback: FixedGenerator(kind: .encouragement, output: nil),
                                       cacheTTL: 5 * 60)
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        await orch.run(for: ctx(now: now), into: container.mainContext)
        await orch.run(for: ctx(now: now.addingTimeInterval(60)),
                        into: container.mainContext)
        XCTAssertEqual(recorder.callCount, 1,
                       "Second call within TTL must reuse the cache")
    }

    func testPersistReplacesByDayKeyAndKind() async throws {
        let existing = makeInsight(kind: .travel, text: "OLD")
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let orch = StickyOrchestrator(generators: [
            FixedGenerator(kind: .travel, output: makeInsight(kind: .travel, text: "NEW"))
        ], fallback: FixedGenerator(kind: .encouragement, output: nil))
        await orch.run(for: ctx(), into: container.mainContext)

        let all = try container.mainContext.fetch(FetchDescriptor<AIInsight>())
        let travels = all.filter { $0.kind == .travel }
        XCTAssertEqual(travels.count, 1)
        XCTAssertEqual(travels.first?.text, "NEW")
    }

    func testDismissedInsightExcludedFromCount() async throws {
        let dismissed = makeInsight(kind: .keyword, text: "Old keyword")
        dismissed.dismissed = true
        container.mainContext.insert(dismissed)
        try container.mainContext.save()

        let orch = StickyOrchestrator(generators: [
            FixedGenerator(kind: .keyword, output: makeInsight(kind: .keyword, text: "Old keyword"))
        ], fallback: FixedGenerator(kind: .encouragement, output: nil))
        await orch.run(for: ctx(), into: container.mainContext)

        let undismissed = try container.mainContext.fetch(
            FetchDescriptor<AIInsight>(predicate: #Predicate { !$0.dismissed }))
        XCTAssertEqual(undismissed.count, 0,
                       "If the new insight text matches a dismissed one, skip it")
    }
}

@MainActor
private final class FixedGenerator: InsightGenerator {
    let kind: InsightKind
    let output: AIInsight?
    init(kind: InsightKind, output: AIInsight?) {
        self.kind = kind
        self.output = output
    }
    func generate(for _: DayContext) async -> AIInsight? { output }
}

@MainActor
private final class CountingGenerator: InsightGenerator {
    let kind: InsightKind
    private(set) var callCount = 0
    init(kind: InsightKind) { self.kind = kind }
    func generate(for day: DayContext) async -> AIInsight? {
        callCount += 1
        return AIInsight(dayKey: day.dayKey, text: "T",
                          colorHex: kind.colorHex, tiltDegrees: 0,
                          kind: kind, priority: kind.defaultPriority)
    }
}
