import Foundation

/// Supported repeat cadences (Phase 35). Deliberately the simple subset:
/// no BYDAY sets, no "last weekday of month" — extend on demand.
enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly
    case monthly
    case yearly

    var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    /// Unit noun for "Every N <unit>s".
    var unitName: String {
        switch self {
        case .daily: "day"
        case .weekly: "week"
        case .monthly: "month"
        case .yearly: "year"
        }
    }
}

/// When a series stops. `onDate` is inclusive of occurrences falling on
/// that calendar day (EventKit `EKRecurrenceEnd(end:)` semantics).
enum RecurrenceEnd: Codable, Equatable, Hashable, Sendable {
    case never
    case onDate(Date)
    case afterCount(Int)
}

/// A repeat rule for an `Event`. Stored directly on the model as a
/// Codable value (same mechanism as `reminders: [Reminder]`).
struct Recurrence: Codable, Equatable, Hashable, Sendable {
    var frequency: RecurrenceFrequency
    var interval: Int
    var end: RecurrenceEnd

    init(frequency: RecurrenceFrequency, interval: Int = 1, end: RecurrenceEnd = .never) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.end = end
    }
}
