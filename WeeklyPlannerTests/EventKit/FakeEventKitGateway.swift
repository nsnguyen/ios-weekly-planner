import EventKit
import Foundation
@testable import WeeklyPlanner

/// Recording in-memory `EventKitGateway`. Objects come from a scratch
/// `EKEventStore` that is never committed to the system calendar.
@MainActor
final class FakeEventKitGateway: EventKitGateway {
    private let scratch = EKEventStore()

    var eventsAuthStatus: EKAuthorizationStatus = .fullAccess
    var remindersAuthStatus: EKAuthorizationStatus = .fullAccess

    private(set) var savedEvents: [(event: EKEvent, span: EKSpan)] = []
    private(set) var removedEvents: [(event: EKEvent, span: EKSpan)] = []
    /// Events returned by `fetchEvents` regardless of range (tests keep
    /// ranges generous, so no filtering logic to get wrong).
    var stubbedEvents: [EKEvent] = []

    func requestEventsAccess() async -> EKAuthorizationStatus { eventsAuthStatus }
    func requestRemindersAccess() async -> EKAuthorizationStatus { remindersAuthStatus }

    func fetchEvents(from _: Date, to _: Date, calendars _: [EKCalendar]?) -> [EKEvent] {
        stubbedEvents
    }

    func fetchReminders(in _: [EKCalendar]?) async -> [EKReminder] { [] }

    func save(_ event: EKEvent, span: EKSpan) throws {
        savedEvents.append((event, span))
    }

    func remove(_ event: EKEvent, span: EKSpan) throws {
        removedEvents.append((event, span))
    }

    func save(_: EKReminder) throws {}
    func remove(_: EKReminder) throws {}

    private(set) var calendars: [EKCalendar] = []
    var eventCalendars: [EKCalendar] { calendars }
    var reminderCalendars: [EKCalendar] { [] }
    var defaultEventCalendarForNewEvents: EKCalendar? { calendars.first }
    var defaultReminderCalendar: EKCalendar? { nil }

    func newEvent() -> EKEvent { EKEvent(eventStore: scratch) }
    func newReminder() -> EKReminder { EKReminder(eventStore: scratch) }

    func newCalendar(for entityType: EKEntityType, source: EKSource?) -> EKCalendar {
        let calendar = EKCalendar(for: entityType, eventStore: scratch)
        if let source { calendar.source = source }
        return calendar
    }

    func saveCalendar(_ calendar: EKCalendar) throws {
        calendars.append(calendar)
    }

    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        calendars.first { $0.calendarIdentifier == identifier }
    }

    var preferredSource: EKSource? { scratch.sources.first }

    var changes: AsyncStream<Void> { AsyncStream { _ in } }
}
