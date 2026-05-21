import Foundation

/// Applies the user's default-reminder preference to a freshly-created
/// `Event`. Called by Phase 18's `InboxStore.accept(id:)` and (later) by
/// Phase 19's manual-add flow.
///
/// No-op when:
/// - The user has chosen "No reminder" (`settings.defaultReminderMinutes == nil`).
/// - The event already has a time-based reminder.
///
/// `Event` is a `@Model final class`, so we mutate `event.reminders` via the
/// class reference — no `inout`.
enum DefaultReminderPolicy {
    static func apply(to event: Event, settings: UserSettings) {
        guard let minutes = settings.defaultReminderMinutes else { return }
        guard event.reminders.contains(where: { $0.isTimeBased }) == false else { return }
        event.reminders.append(.timeBefore(minutes: minutes))
    }
}

extension Reminder {
    /// True when this reminder fires at a time offset from event start
    /// (as opposed to a location-arrival trigger). Used by
    /// `DefaultReminderPolicy` to avoid stacking duplicate time reminders.
    var isTimeBased: Bool {
        if case .timeBefore = self { return true }
        return false
    }
}
