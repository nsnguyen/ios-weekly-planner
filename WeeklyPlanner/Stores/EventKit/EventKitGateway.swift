import EventKit
import Foundation

/// Thin facade over `EKEventStore`. All EventKit access in the app flows
/// through this protocol so:
///   1. Tests can substitute a `FakeEventKitGateway`.
///   2. Real `EKEventStore` and `EKEvent` references stay out of the rest
///      of the app — `EventKitSync` and the decorators see only our own
///      `Event` / `TaskItem` types or string identifiers.
///
/// Sendability: `EKEventStore` and `EKEvent` aren't `Sendable`. Gateway
/// methods are `@MainActor` so callers must already be on main. EventKit
/// change notifications are forwarded via an `AsyncStream<Void>` — listeners
/// re-fetch.
@MainActor
protocol EventKitGateway: AnyObject {
    var eventsAuthStatus: EKAuthorizationStatus { get }
    var remindersAuthStatus: EKAuthorizationStatus { get }

    func requestEventsAccess() async -> EKAuthorizationStatus
    func requestRemindersAccess() async -> EKAuthorizationStatus

    /// Returns raw `EKEvent`s in the given window across the supplied
    /// calendars (or all calendars if `calendars` is `nil`).
    func fetchEvents(from: Date, to: Date, calendars: [EKCalendar]?) -> [EKEvent]

    /// All incomplete reminders across `calendars` (or all if `nil`).
    func fetchReminders(in calendars: [EKCalendar]?) async -> [EKReminder]

    func save(_ event: EKEvent) throws
    func remove(_ event: EKEvent) throws
    func save(_ reminder: EKReminder) throws
    func remove(_ reminder: EKReminder) throws

    /// All user calendars for events. Used by `CategoryCalendarManager`.
    var eventCalendars: [EKCalendar] { get }
    var reminderCalendars: [EKCalendar] { get }
    var defaultEventCalendarForNewEvents: EKCalendar? { get }
    var defaultReminderCalendar: EKCalendar? { get }

    /// Creates a new empty event/reminder bound to the underlying store.
    /// Callers populate fields then pass to `save(_:)`.
    func newEvent() -> EKEvent
    func newReminder() -> EKReminder
    func newCalendar(for entityType: EKEntityType, source: EKSource?) -> EKCalendar

    func saveCalendar(_ calendar: EKCalendar) throws
    func calendar(withIdentifier: String) -> EKCalendar?

    /// Local sources to host our category calendars. iCloud preferred if
    /// available; falls back to local.
    var preferredSource: EKSource? { get }

    /// Fires every time EventKit posts `EKEventStoreChangedNotification`.
    /// Subscribers should re-fetch their visible window.
    var changes: AsyncStream<Void> { get }
}

/// Production gateway backed by the system `EKEventStore`.
@MainActor
final class SystemEventKitGateway: EventKitGateway {
    private let store: EKEventStore
    private nonisolated(unsafe) var notificationToken: (any NSObjectProtocol)?
    private let continuation: AsyncStream<Void>.Continuation
    let changes: AsyncStream<Void>

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
        var continuation: AsyncStream<Void>.Continuation!
        changes = AsyncStream { continuation = $0 }
        self.continuation = continuation

        notificationToken = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged,
                                                                   object: store,
                                                                   queue: .main)
        { [continuation] _ in
            continuation?.yield()
        }
    }

    deinit {
        if let notificationToken {
            NotificationCenter.default.removeObserver(notificationToken)
        }
        continuation.finish()
    }

    var eventsAuthStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var remindersAuthStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    func requestEventsAccess() async -> EKAuthorizationStatus {
        _ = try? await store.requestFullAccessToEvents()
        return eventsAuthStatus
    }

    func requestRemindersAccess() async -> EKAuthorizationStatus {
        _ = try? await store.requestFullAccessToReminders()
        return remindersAuthStatus
    }

    func fetchEvents(from start: Date, to end: Date, calendars: [EKCalendar]?) -> [EKEvent] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate)
    }

    func fetchReminders(in calendars: [EKCalendar]?) async -> [EKReminder] {
        let predicate = store.predicateForReminders(in: calendars)
        let box: ReminderBox = await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { reminders in
                cont.resume(returning: ReminderBox(reminders: reminders ?? []))
            }
        }
        return box.reminders
    }

    func save(_ event: EKEvent) throws {
        try store.save(event, span: .thisEvent, commit: true)
    }

    func remove(_ event: EKEvent) throws {
        try store.remove(event, span: .thisEvent, commit: true)
    }

    func save(_ reminder: EKReminder) throws {
        try store.save(reminder, commit: true)
    }

    func remove(_ reminder: EKReminder) throws {
        try store.remove(reminder, commit: true)
    }

    var eventCalendars: [EKCalendar] {
        store.calendars(for: .event)
    }

    var reminderCalendars: [EKCalendar] {
        store.calendars(for: .reminder)
    }

    var defaultEventCalendarForNewEvents: EKCalendar? {
        store.defaultCalendarForNewEvents
    }

    var defaultReminderCalendar: EKCalendar? {
        store.defaultCalendarForNewReminders()
    }

    func newEvent() -> EKEvent {
        EKEvent(eventStore: store)
    }

    func newReminder() -> EKReminder {
        EKReminder(eventStore: store)
    }

    func newCalendar(for entityType: EKEntityType, source: EKSource?) -> EKCalendar {
        let calendar = EKCalendar(for: entityType, eventStore: store)
        calendar.source = source ?? preferredSource ?? store.sources.first ?? store.defaultCalendarForNewEvents?.source
        return calendar
    }

    func saveCalendar(_ calendar: EKCalendar) throws {
        try store.saveCalendar(calendar, commit: true)
    }

    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        store.calendar(withIdentifier: identifier)
    }

    var preferredSource: EKSource? {
        store.sources.first(where: { $0.sourceType == .calDAV })
            ?? store.sources.first(where: { $0.sourceType == .local })
            ?? store.sources.first
    }
}

/// `[EKReminder]` is not `Sendable`, so the value returned from
/// `EKEventStore.fetchReminders(matching:)`'s completion handler can't cross
/// an actor boundary directly. This `@unchecked Sendable` box smuggles it.
/// Safe because the array contents are only read on `@MainActor` afterwards.
private final class ReminderBox: @unchecked Sendable {
    let reminders: [EKReminder]
    init(reminders: [EKReminder]) {
        self.reminders = reminders
    }
}
