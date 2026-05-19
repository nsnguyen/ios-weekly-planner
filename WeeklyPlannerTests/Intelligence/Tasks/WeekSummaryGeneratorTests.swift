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

    func testGenerateProducesSummaryWhenAvailable() async throws {
        let service = StubIntelligenceService(eventStore: eventStore)
        let generator = WeekSummaryGenerator(
            intelligence: service,
            events: eventStore,
            tasks: taskStore
        )
        let summary = try await generator.generate(weekOffset: 0, today: Self.may16_2026())
        XCTAssertFalse(summary.headline.isEmpty)
        XCTAssertEqual(summary.completionPercent, 0.0, accuracy: 0.01)
    }

    func testGenerateFallsBackWhenAIDisabled() async throws {
        let service = StubIntelligenceService(eventStore: eventStore)
        let generator = WeekSummaryGenerator(
            intelligence: service,
            events: eventStore,
            tasks: taskStore,
            settings: { false }
        )
        let summary = try await generator.generate(weekOffset: 0, today: Self.may16_2026())
        XCTAssertTrue(summary.headline.contains("balanced week"))
        XCTAssertEqual(summary.bullets.count, 3)
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
