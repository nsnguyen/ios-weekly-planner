import XCTest
import UserNotifications
@testable import WeeklyPlanner

@MainActor
final class TaskNotificationSchedulerTests: XCTestCase {

    private var center: FakeNotificationCenter!
    private var locations: FakeLocationRegistrar!
    private var scheduler: TaskNotificationScheduler!

    override func setUp() async throws {
        center = FakeNotificationCenter()
        locations = FakeLocationRegistrar()
        scheduler = TaskNotificationScheduler(center: center, locationRegistrar: locations)
    }

    func testScheduleReminderTimeProducesCalendarRequest() async throws {
        let due = Date().addingTimeInterval(7 * 24 * 3600)   // 1 week from now
        let task = TaskItem(title: "Pay rent", due: due, category: .personal, reminderTime: due)

        try await scheduler.schedule(task: task)

        XCTAssertEqual(center.addedRequests.count, 1)
        let req = try XCTUnwrap(center.addedRequests.first)
        XCTAssertEqual(req.identifier, "task-\(task.id.uuidString)-time")
        XCTAssertNotNil(req.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(req.content.categoryIdentifier, NotificationCategoryIDs.task)
    }

    func testScheduleLocationReminderRegistersRegion() async throws {
        let due = Date().addingTimeInterval(60 * 60 * 24 * 2)
        let task = TaskItem(
            title: "Pick up keys",
            due: due,
            category: .personal,
            locationReminder: LocationReminder(name: "Marina",
                                               latitude: 37.806,
                                               longitude: -122.432,
                                               radiusMeters: 150)
        )
        try await scheduler.schedule(task: task)

        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(locations.registered.count, 1)
        XCTAssertEqual(locations.registered.first?.eventID, task.id)
    }

    func testCancelByTaskIDClearsRequestsAndRegions() async throws {
        let due = Date().addingTimeInterval(7 * 24 * 3600)   // 1 week from now
        let task = TaskItem(title: "Pay rent", due: due, category: .personal, reminderTime: due)
        try await scheduler.schedule(task: task)
        XCTAssertEqual(center.addedRequests.count, 1)

        await scheduler.cancel(taskID: task.id)

        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(locations.unregistered.last, task.id)
    }

    func testNoReminderFieldsSchedulesNothing() async throws {
        let due = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let task = TaskItem(title: "Read book", due: due, category: .personal)   // No reminders at all.

        try await scheduler.schedule(task: task)

        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertTrue(locations.registered.isEmpty)
    }
}
