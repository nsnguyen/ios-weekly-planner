import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class SummarizeWeekToolTests: XCTestCase {
    private var container: ModelContainer!
    private var events: SwiftDataEventStore!
    private var tasks: SwiftDataTaskStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        events = SwiftDataEventStore(context: container.mainContext)
        tasks = SwiftDataTaskStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        events = nil; tasks = nil; container = nil
        try await super.tearDown()
    }

    func testAggregatesHoursByCategoryAndTaskCounts() async throws {
        let today = Self.may16_2026(hour: 9)
        try await events.upsert(Event(title: "Standup", start: today,
                                      end: today.addingTimeInterval(1800), category: .work))
        try await events.upsert(Event(title: "Run", start: today.addingTimeInterval(3600),
                                      end: today.addingTimeInterval(5400), category: .health))
        try await tasks.upsert(TaskItem(title: "Done one", due: today, done: true,
                                        priority: .med, category: .work))
        try await tasks.upsert(TaskItem(title: "Open one", due: today, done: false,
                                        priority: .med, category: .personal))

        let tool = SummarizeWeekTool(events: events, tasks: tasks)
        let summary = try await tool.run(weekOffset: 0, today: today)

        XCTAssertEqual(summary.hoursByCategory["work"] ?? 0, 0.5, accuracy: 0.01)
        XCTAssertEqual(summary.hoursByCategory["health"] ?? 0, 0.5, accuracy: 0.01)
        XCTAssertEqual(summary.tasksDone, 1)
        XCTAssertEqual(summary.tasksOpen, 1)
        XCTAssertEqual(summary.highlightEventIDs.count, 2)
    }

    private static func may16_2026(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
