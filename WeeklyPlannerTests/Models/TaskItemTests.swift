import Foundation
import XCTest
@testable import WeeklyPlanner

final class TaskItemTests: XCTestCase {
    func testPriorityOrderingHighestFirstWhenDescending() {
        let items: [Priority] = [.low, .high, .med, .high, .low]
        let descending = items.sorted(by: >)
        XCTAssertEqual(descending, [.high, .high, .med, .low, .low])
    }

    func testReminderTextDefaultsToNil() {
        let task = TaskItem(title: "Buy milk", due: .init(), category: .personal)
        XCTAssertNil(task.reminderText)
        XCTAssertNil(task.reminderTime)
        XCTAssertNil(task.locationReminder)
        XCTAssertEqual(task.priority, .med)
        XCTAssertFalse(task.done)
    }

    func testCategoryAccessorRoundTrip() {
        let task = TaskItem(title: "Train", due: .init(), category: .health)
        XCTAssertEqual(task.category, .health)
        task.category = .focus
        XCTAssertEqual(task.categoryRaw, "focus")
    }

    func testPriorityAccessorRoundTrip() {
        let task = TaskItem(title: "Train", due: .init(), priority: .high, category: .health)
        XCTAssertEqual(task.priority, .high)
        task.priority = .low
        XCTAssertEqual(task.priorityRaw, "low")
    }
}
