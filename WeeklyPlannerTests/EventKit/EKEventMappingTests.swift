import EventKit
import Foundation
import XCTest
@testable import WeeklyPlanner

final class EKEventMappingTests: XCTestCase {
    /// A scratch `EKEventStore` for object construction only. Never saves
    /// to the real Calendar — that needs permission and a simulator setup.
    private let scratchStore = EKEventStore()

    private func makeBlankEKEvent() -> EKEvent {
        EKEvent(eventStore: scratchStore)
    }

    // MARK: - Round-trip

    func testOutboundApplyPreservesCoreFields() {
        let event = Event(title: "Standup",
                          start: Date(timeIntervalSinceReferenceDate: 1_000_000),
                          end: Date(timeIntervalSinceReferenceDate: 1_003_600),
                          location: "Zoom",
                          category: .work)
        let ek = makeBlankEKEvent()
        EKEventMapping.apply(event, to: ek, calendar: nil)

        XCTAssertEqual(ek.title, "Standup")
        XCTAssertEqual(ek.startDate, event.start)
        XCTAssertEqual(ek.endDate, event.end)
        XCTAssertEqual(ek.location, "Zoom")
        XCTAssertNotNil(ek.notes)
        XCTAssertTrue(ek.notes?.contains("planner-meta") ?? false)
    }

    func testNotesMetaRoundTripPreservesGmailFields() {
        let event = Event(title: "Lunch",
                          start: .init(),
                          end: .init().addingTimeInterval(3600),
                          category: .personal,
                          source: .gmail,
                          gmailMessageID: "abc123",
                          gmailFrom: "alice@example.com",
                          gmailSubject: "Want to grab lunch?")
        let ek = makeBlankEKEvent()
        EKEventMapping.apply(event, to: ek, calendar: nil)

        let decoded = EKEventMapping.toEvent(ek)
        XCTAssertEqual(decoded.source, .gmail)
        XCTAssertEqual(decoded.gmailMessageID, "abc123")
        XCTAssertEqual(decoded.gmailFrom, "alice@example.com")
        XCTAssertEqual(decoded.gmailSubject, "Want to grab lunch?")
        XCTAssertEqual(decoded.category, .personal)
    }

    func testDecodeMetaReturnsNilForPlainNotes() {
        XCTAssertNil(EKEventMapping.decodeMeta(from: ""))
        XCTAssertNil(EKEventMapping.decodeMeta(from: "Just a plain note from another app"))
    }

    func testUserNotesStripsMetaMarker() {
        let event = Event(title: "T", start: .init(), end: .init(), category: .work)
        let ek = makeBlankEKEvent()
        EKEventMapping.apply(event, to: ek, calendar: nil)
        XCTAssertEqual(EKEventMapping.userNotes(from: ek.notes), "")
    }

    // MARK: - Alarms

    func testTimeBeforeReminderMapsToNegativeRelativeOffset() {
        let event = Event(title: "Sync",
                          start: .init(),
                          end: .init().addingTimeInterval(1800),
                          category: .work,
                          reminders: [.timeBefore(minutes: 15)])
        let ek = makeBlankEKEvent()
        EKEventMapping.apply(event, to: ek, calendar: nil)

        XCTAssertEqual(ek.alarms?.count, 1)
        let alarm = ek.alarms?.first
        XCTAssertEqual(alarm?.relativeOffset, -15 * 60)
    }

    func testOnArriveReminderMapsToStructuredLocationAlarm() {
        let location = LocationReminder(name: "Office", latitude: 37.7, longitude: -122.4, radiusMeters: 150)
        let event = Event(title: "Standup",
                          start: .init(),
                          end: .init(),
                          category: .work,
                          reminders: [.onArrive(location)])
        let ek = makeBlankEKEvent()
        EKEventMapping.apply(event, to: ek, calendar: nil)

        let alarm = ek.alarms?.first
        XCTAssertNotNil(alarm?.structuredLocation)
        XCTAssertEqual(alarm?.structuredLocation?.title, "Office")
        XCTAssertEqual(alarm?.proximity, .enter)
        XCTAssertEqual(alarm?.structuredLocation?.radius, 150)
    }

    func testAlarmRoundTripPreservesReminderArray() {
        let event = Event(title: "T",
                          start: .init(),
                          end: .init().addingTimeInterval(3600),
                          category: .work,
                          reminders: [.timeBefore(minutes: 30)])
        let ek = makeBlankEKEvent()
        EKEventMapping.apply(event, to: ek, calendar: nil)

        let decoded = EKEventMapping.toEvent(ek)
        XCTAssertEqual(decoded.reminders, [.timeBefore(minutes: 30)])
    }

    func testApplyWritesRecurrenceRule() {
        let event = Event(title: "Gym",
                          start: Date(timeIntervalSinceReferenceDate: 1_000_000),
                          end: Date(timeIntervalSinceReferenceDate: 1_003_600),
                          category: .health,
                          recurrence: Recurrence(frequency: .weekly, interval: 2, end: .afterCount(8)))
        let ek = makeBlankEKEvent()
        EKEventMapping.apply(event, to: ek, calendar: nil)

        XCTAssertEqual(ek.recurrenceRules?.count, 1)
        XCTAssertEqual(ek.recurrenceRules?.first?.frequency, .weekly)
        XCTAssertEqual(ek.recurrenceRules?.first?.interval, 2)
        XCTAssertEqual(ek.recurrenceRules?.first?.recurrenceEnd?.occurrenceCount, 8)
    }

    func testApplyClearsRuleWhenRecurrenceRemoved() {
        let ek = makeBlankEKEvent()
        ek.recurrenceRules = [RecurrenceMapper.toEKRule(Recurrence(frequency: .daily))]

        let single = Event(title: "One-off",
                           start: Date(timeIntervalSinceReferenceDate: 1_000_000),
                           end: Date(timeIntervalSinceReferenceDate: 1_003_600),
                           category: .personal)
        EKEventMapping.apply(single, to: ek, calendar: nil)

        XCTAssertTrue(ek.recurrenceRules?.isEmpty ?? true,
                      "Editing a series to not-repeating must clear the EK rule")
    }

    func testToEventReadsRecurrenceBack() {
        let ek = makeBlankEKEvent()
        ek.title = "Gym"
        ek.startDate = Date(timeIntervalSinceReferenceDate: 1_000_000)
        ek.endDate = Date(timeIntervalSinceReferenceDate: 1_003_600)
        ek.recurrenceRules = [RecurrenceMapper.toEKRule(Recurrence(frequency: .monthly, interval: 3))]

        let event = EKEventMapping.toEvent(ek)
        XCTAssertEqual(event.recurrence, Recurrence(frequency: .monthly, interval: 3))
        XCTAssertTrue(event.isRecurring)
    }
}
