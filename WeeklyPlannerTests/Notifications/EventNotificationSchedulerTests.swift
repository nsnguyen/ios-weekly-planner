import XCTest
import UserNotifications
@testable import WeeklyPlanner

@MainActor
final class EventNotificationSchedulerTests: XCTestCase {

    private var center: FakeNotificationCenter!
    private var locations: FakeLocationRegistrar!
    private var scheduler: EventNotificationScheduler!

    override func setUp() async throws {
        center = FakeNotificationCenter()
        locations = FakeLocationRegistrar()
        scheduler = EventNotificationScheduler(center: center, locationRegistrar: locations)
    }

    func testScheduleTimeReminderProducesCalendarRequest() async throws {
        let start = Date().addingTimeInterval(7 * 24 * 3600)   // 1 week from now
        let event = Event(
            title: "Lunch with Sara",
            start: start,
            end: start.addingTimeInterval(3600),
            location: "Café Bleu",
            category: .personal,
            reminders: [.timeBefore(minutes: 15)]
        )

        try await scheduler.schedule(event: event)

        XCTAssertEqual(center.addedRequests.count, 1)
        let req = try XCTUnwrap(center.addedRequests.first)
        XCTAssertEqual(req.identifier, "event-\(event.id.uuidString)-time-15")
        XCTAssertNotNil(req.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(req.content.title, "Lunch with Sara")
    }

    func testScheduleArrivalRegistersRegion() async throws {
        let start = Date().addingTimeInterval(60 * 60 * 24 * 2)
        let event = Event(
            title: "Sara's Birthday",
            start: start,
            end: start.addingTimeInterval(3600),
            location: "Trick Dog",
            category: .personal,
            reminders: [.onArrive(LocationReminder(name: "Trick Dog",
                                                  latitude: 37.759,
                                                  longitude: -122.412,
                                                  radiusMeters: 150))]
        )

        try await scheduler.schedule(event: event)

        XCTAssertEqual(locations.registered.count, 1)
        let registered = try XCTUnwrap(locations.registered.first)
        XCTAssertEqual(registered.eventID, event.id)
        XCTAssertEqual(registered.reminder.name, "Trick Dog")
    }

    func testRescheduleClearsOldRequestsByPrefix() async throws {
        let start = Date().addingTimeInterval(7 * 24 * 3600)   // 1 week from now
        let event = Event(
            title: "Lunch",
            start: start,
            end: start.addingTimeInterval(3600),
            category: .personal,
            reminders: [.timeBefore(minutes: 15)]
        )

        try await scheduler.schedule(event: event)
        XCTAssertEqual(center.addedRequests.count, 1)
        // Change reminders, schedule again.
        event.reminders = [.timeBefore(minutes: 30)]
        try await scheduler.schedule(event: event)

        XCTAssertEqual(center.addedRequests.count, 1, "Old request should have been cleared before adding the new one")
        XCTAssertEqual(center.addedRequests.first?.identifier, "event-\(event.id.uuidString)-time-30")
        XCTAssertTrue(center.removedIdentifiers.contains("event-\(event.id.uuidString)-time-15"))
    }

    func testCancelByEventIDRemovesAllRequests() async throws {
        let start = Date().addingTimeInterval(7 * 24 * 3600)   // 1 week from now
        let event = Event(
            title: "Lunch",
            start: start,
            end: start.addingTimeInterval(3600),
            category: .personal,
            reminders: [.timeBefore(minutes: 15), .timeBefore(minutes: 60)]
        )
        try await scheduler.schedule(event: event)
        XCTAssertEqual(center.addedRequests.count, 2)

        await scheduler.cancel(eventID: event.id)

        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(locations.unregistered.last, event.id)
    }

    func testPastTimeReminderIsSkipped() async throws {
        // Reminder time would land in the past — scheduler should not add it.
        let start = Date().addingTimeInterval(60)            // 1 min from now
        let event = Event(
            title: "Imminent",
            start: start,
            end: start.addingTimeInterval(3600),
            category: .personal,
            reminders: [.timeBefore(minutes: 15)]            // -14 min from now
        )
        try await scheduler.schedule(event: event)
        XCTAssertTrue(center.addedRequests.isEmpty)
    }
}

/// In-test fake for `LocationRegistering`. Just records inputs.
@MainActor
final class FakeLocationRegistrar: LocationRegistering {
    struct Registration {
        let eventID: UUID
        let reminder: LocationReminder
        let proximityInDays: Int
    }

    private(set) var registered: [Registration] = []
    private(set) var unregistered: [UUID] = []
    var stubAcceptsAll: Bool = true

    func register(eventID: UUID,
                  reminder: LocationReminder,
                  content: @escaping () -> UNMutableNotificationContent,
                  proximityInDays: Int) -> String?
    {
        registered.append(.init(eventID: eventID, reminder: reminder, proximityInDays: proximityInDays))
        return stubAcceptsAll ? "event-\(eventID.uuidString)-arrive" : nil
    }

    func unregister(eventID: UUID) {
        unregistered.append(eventID)
    }
}
