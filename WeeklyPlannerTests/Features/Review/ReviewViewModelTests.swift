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

    func testFallbackSummaryUsedWhenGeneratorNil() async {
        let vm = ReviewViewModel(weekOffset: 0,
                                  eventStore: eventStore,
                                  taskStore: taskStore,
                                  summaryGenerator: nil,
                                  clock: { Self.may18_2026(hour: 12) })
        await vm.refresh()
        XCTAssertTrue(vm.summary.headline.contains("balanced week"))
        XCTAssertEqual(vm.summary.bullets.count, 3)
    }

    func testHardcodedMorningRunStreakAlwaysPresent() async {
        let vm = ReviewViewModel(weekOffset: 0,
                                  eventStore: eventStore,
                                  taskStore: taskStore,
                                  summaryGenerator: nil,
                                  clock: { Self.may18_2026(hour: 12) })
        await vm.refresh()
        XCTAssertEqual(vm.streaks.count, 1)
        XCTAssertEqual(vm.streaks.first?.name, "Morning run")
        XCTAssertEqual(vm.streaks.first?.emoji, "🏃")
        XCTAssertEqual(vm.streaks.first?.last7Days.count, 7)
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
