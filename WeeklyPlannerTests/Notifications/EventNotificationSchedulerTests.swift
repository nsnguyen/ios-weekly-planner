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

    func testRecurringEventSchedulesOnlyWindowedOccurrences() async throws {
        // Weekly with a 15-min alert: a 30-day window holds 4–5 occurrences.
        let start = Date().addingTimeInterval(2 * 24 * 3600)
        let event = Event(title: "Gym",
                          start: start,
                          end: start.addingTimeInterval(3600),
                          category: .health,
                          reminders: [.timeBefore(minutes: 15)],
                          recurrence: Recurrence(frequency: .weekly))

        try await scheduler.schedule(event: event)

        XCTAssertGreaterThanOrEqual(center.addedRequests.count, 4)
        XCTAssertLessThanOrEqual(center.addedRequests.count, 5)
        XCTAssertEqual(Set(center.addedRequests.map(\.identifier)).count,
                       center.addedRequests.count,
                       "Each occurrence needs a distinct identifier")
        XCTAssertTrue(center.addedRequests.allSatisfy {
            $0.identifier.hasPrefix("event-\(event.id.uuidString)-")
        }, "Identifiers must keep the event prefix so re-schedules can purge them")
    }

    func testDailyRecurringIsCappedAtMaxOccurrences() async throws {
        let start = Date().addingTimeInterval(24 * 3600)
        let event = Event(title: "Walk",
                          start: start,
                          end: start.addingTimeInterval(1800),
                          category: .health,
                          reminders: [.timeBefore(minutes: 5)],
                          recurrence: Recurrence(frequency: .daily))

        try await scheduler.schedule(event: event)

        XCTAssertEqual(center.addedRequests.count, 8,
                       "30-day daily series must cap at the max-occurrence bound")
    }

    func testExcludedOccurrenceIsNotScheduled() async throws {
        let start = Date().addingTimeInterval(24 * 3600)
        let excluded = start.addingTimeInterval(7 * 24 * 3600)
        let event = Event(title: "Gym",
                          start: start,
                          end: start.addingTimeInterval(3600),
                          category: .health,
                          reminders: [.timeBefore(minutes: 15)],
                          recurrence: Recurrence(frequency: .weekly),
                          excludedOccurrenceStarts: [excluded])

        try await scheduler.schedule(event: event)

        let expectedExcludedFire = excluded.addingTimeInterval(-15 * 60)
        for request in center.addedRequests {
            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let fire = Calendar.current.date(from: trigger.dateComponents)
            {
                XCTAssertGreaterThan(abs(fire.timeIntervalSince(expectedExcludedFire)), 60,
                                     "Excluded occurrence must not get a reminder")
            }
        }
    }

    func testSingleEventIdentifiersUnchanged() async throws {
        // Phase 19 contract: single events keep "event-<id>-time-<min>".
        let start = Date().addingTimeInterval(7 * 24 * 3600)
        let event = Event(title: "Lunch",
                          start: start,
                          end: start.addingTimeInterval(3600),
                          category: .personal,
                          reminders: [.timeBefore(minutes: 15)])

        try await scheduler.schedule(event: event)

        XCTAssertEqual(center.addedRequests.map(\.identifier),
                       ["event-\(event.id.uuidString)-time-15"])
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
