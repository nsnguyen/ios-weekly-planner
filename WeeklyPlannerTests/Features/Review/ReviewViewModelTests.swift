import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class ReviewViewModelTests: XCTestCase {
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

    func testTimeByCategorySumsCorrectly() async throws {
        let monday = Self.may18_2026(hour: 9)
        try await eventStore.upsert(Event(title: "Standup",
                                          start: monday,
                                          end: monday.addingTimeInterval(1800),
                                          category: .work))
        try await eventStore.upsert(Event(title: "Run",
                                          start: monday.addingTimeInterval(3600),
                                          end: monday.addingTimeInterval(7200),
                                          category: .health))

        let vm = ReviewViewModel(weekOffset: 0,
                                  eventStore: eventStore,
                                  taskStore: taskStore,
                                  summaryGenerator: nil,
                                  clock: { Self.may18_2026(hour: 12) })
        await vm.refresh()

        XCTAssertEqual(vm.timeByCategory[.work] ?? 0, 0.5, accuracy: 0.01)
        XCTAssertEqual(vm.timeByCategory[.health] ?? 0, 1.0, accuracy: 0.01)
        XCTAssertEqual(vm.maxHours, 1.0, accuracy: 0.01)
    }

    func testCompletionPercentMatchesTaskCounts() async throws {
        let monday = Self.may18_2026(hour: 9)
        try await taskStore.upsert(TaskItem(title: "A", due: monday, done: true,
                                            priority: .med, category: .work))
        try await taskStore.upsert(TaskItem(title: "B", due: monday, done: true,
                                            priority: .med, category: .work))
        try await taskStore.upsert(TaskItem(title: "C", due: monday, done: false,
                                            priority: .med, category: .work))

        let vm = ReviewViewModel(weekOffset: 0,
                                  eventStore: eventStore,
                                  taskStore: taskStore,
                                  summaryGenerator: nil,
                                  clock: { Self.may18_2026(hour: 12) })
        await vm.refresh()

        XCTAssertEqual(vm.tasksDone, 2)
        XCTAssertEqual(vm.tasksTotal, 3)
        XCTAssertEqual(vm.completionPercent, 2.0 / 3.0, accuracy: 0.01)
    }

    // MARK: - Phase 32 (#38): three honest summary states

    func testSummaryStateIsAIOffWhenGeneratorNil() async {
        let vm = ReviewViewModel(weekOffset: 0,
                                  eventStore: eventStore,
                                  taskStore: taskStore,
                                  summaryGenerator: nil,
                                  clock: { Self.may18_2026(hour: 12) })
        await vm.refresh()
        XCTAssertEqual(vm.summaryState, .aiOff)
    }

    func testSummaryStateIsAIOffWhenSettingsToggleOff() async {
        let generator = WeekSummaryGenerator(
            intelligence: StubIntelligenceService(eventStore: eventStore),
            events: eventStore,
            tasks: taskStore,
            settings: { false })
        let vm = ReviewViewModel(weekOffset: 0,
                                  eventStore: eventStore,
                                  taskStore: taskStore,
                                  summaryGenerator: generator,
                                  clock: { Self.may18_2026(hour: 12) })
        await vm.refresh()
        XCTAssertEqual(vm.summaryState, .aiOff)
    }

    func testSummaryStateHiddenForEmptyWeekWithAIOn() async {
        let generator = WeekSummaryGenerator(
            intelligence: StubIntelligenceService(eventStore: eventStore),
            events: eventStore,
            tasks: taskStore)
        let vm = ReviewViewModel(weekOffset: 0,
                                  eventStore: eventStore,
                                  taskStore: taskStore,
                                  summaryGenerator: generator,
                                  clock: { Self.may18_2026(hour: 12) })
        await vm.refresh()
        XCTAssertEqual(vm.summaryState, .hidden)
    }

    func testSummaryStateRealCarriesModelOutputAndNoPlaceholders() async throws {
        let monday = Self.may18_2026(hour: 9)
        try await eventStore.upsert(Event(title: "Standup",
                                          start: monday,
                                          end: monday.addingTimeInterval(1800),
                                          category: .work))
        let generator = WeekSummaryGenerator(
            intelligence: StubIntelligenceService(eventStore: eventStore),
            events: eventStore,
            tasks: taskStore)
        let vm = ReviewViewModel(weekOffset: 0,
                                  eventStore: eventStore,
                                  taskStore: taskStore,
                                  summaryGenerator: generator,
                                  clock: { Self.may18_2026(hour: 12) })
        await vm.refresh()
        guard case .real(let summary) = vm.summaryState else {
            return XCTFail("expected .real, got \(vm.summaryState)")
        }
        XCTAssertFalse(summary.headline.isEmpty)
        XCTAssertTrue(summary.bullets.isEmpty,
                      "no design-placeholder bullets alongside real output")
    }

    func testNoFabricatedStreaksInAnyState() async {
        let vm = ReviewViewModel(weekOffset: 0,
                                  eventStore: eventStore,
                                  taskStore: taskStore,
                                  summaryGenerator: nil,
                                  clock: { Self.may18_2026(hour: 12) })
        await vm.refresh()
        XCTAssertTrue(vm.streaks.isEmpty,
                      "no real StreakStore exists yet — streaks must never be fabricated")
        XCTAssertFalse(vm.streaks.contains { $0.name == "Morning run" })
    }

    func testAIOffPromptCopyNamesAskThePlanner() {
        XCTAssertEqual(ReviewAIOffPrompt.promptText,
                       "Turn on Ask the planner for a weekly summary")
        XCTAssertFalse(ReviewAIOffPrompt.promptText.contains("Apple Intelligence"))
    }

    private static func may18_2026(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 18
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
