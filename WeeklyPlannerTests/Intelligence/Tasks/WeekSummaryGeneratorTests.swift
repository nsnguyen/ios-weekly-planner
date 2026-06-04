import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class WeekSummaryGeneratorTests: XCTestCase {
    private var container: ModelContainer!
    private var eventStore: SwiftDataEventStore!
    private var taskStore: SwiftDataTaskStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        eventStore = SwiftDataEventStore(context: container.mainContext)
        taskStore = SwiftDataTaskStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        eventStore = nil; taskStore = nil; container = nil
        try await super.tearDown()
    }

    func testPromptIncludesWeekStatsLines() {
        let prompt = WeekSummaryGenerator.prompt(
            weekOffset: 0,
            tasksDone: 4,
            tasksTotal: 9,
            hoursByCategory: ["work": 12.5, "health": 2.0]
        )
        XCTAssertTrue(prompt.contains("Week offset: 0"))
        XCTAssertTrue(prompt.contains("Tasks: 4 of 9 done"))
        XCTAssertTrue(prompt.contains("work: 12.5h"))
        XCTAssertTrue(prompt.contains("health: 2.0h"))
        XCTAssertTrue(prompt.contains("≤ 2 sentences"))
    }

    func testGenerateProducesRealSummaryWhenAvailable() async throws {
        let saturday = Self.may16_2026()
        try await eventStore.upsert(Event(title: "Standup",
                                          start: saturday.addingTimeInterval(-3600),
                                          end: saturday.addingTimeInterval(-1800),
                                          category: .work))
        let service = StubIntelligenceService(eventStore: eventStore)
        let generator = WeekSummaryGenerator(
            intelligence: service,
            events: eventStore,
            tasks: taskStore
        )
        let outcome = await generator.generate(weekOffset: 0, today: saturday)
        guard case .generated(let summary) = outcome else {
            return XCTFail("expected .generated, got \(outcome)")
        }
        XCTAssertFalse(summary.headline.isEmpty)
        XCTAssertTrue(summary.bullets.isEmpty,
                      "real AI output must not carry design-placeholder bullets")
        XCTAssertFalse(summary.headline.contains("balanced week"),
                       "canned fallback copy must not leak into real output")
    }

    func testGenerateReturnsUnavailableWhenAIDisabled() async {
        let service = StubIntelligenceService(eventStore: eventStore)
        let generator = WeekSummaryGenerator(
            intelligence: service,
            events: eventStore,
            tasks: taskStore,
            settings: { false }
        )
        let outcome = await generator.generate(weekOffset: 0, today: Self.may16_2026())
        XCTAssertEqual(outcome, .unavailable)
    }

    func testGenerateReturnsNoContentForGenuinelyEmptyWeek() async {
        let service = StubIntelligenceService(eventStore: eventStore)
        let generator = WeekSummaryGenerator(
            intelligence: service,
            events: eventStore,
            tasks: taskStore
        )
        let outcome = await generator.generate(weekOffset: 0, today: Self.may16_2026())
        XCTAssertEqual(outcome, .noContent,
                       "an empty week must not invoke the model or fabricate a summary")
    }

    private static func may16_2026() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = 12
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
