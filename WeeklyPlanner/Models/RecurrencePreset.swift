import Foundation

/// Discoverable repeat presets for the event sheet (Phase 42 #71).
/// Wraps the existing `Recurrence` model — `interval` support already
/// exists; presets only make it reachable without the steppers.
enum RecurrencePreset: CaseIterable, Equatable {
    case none
    case daily
    case weekly
    case everyTwoWeeks
    case monthly
    case yearly
    case custom

    var displayName: String {
        switch self {
        case .none: "None"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .everyTwoWeeks: "Every 2 weeks"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .custom: "Custom…"
        }
    }

    /// The rule this preset stands for. `.custom` seeds weekly/1 as a
    /// starting point for the steppers.
    var recurrence: Recurrence? {
        switch self {
        case .none: nil
        case .daily: Recurrence(frequency: .daily)
        case .weekly: Recurrence(frequency: .weekly)
        case .everyTwoWeeks: Recurrence(frequency: .weekly, interval: 2)
        case .monthly: Recurrence(frequency: .monthly)
        case .yearly: Recurrence(frequency: .yearly)
        case .custom: Recurrence(frequency: .weekly)
        }
    }

    /// Which preset a stored rule corresponds to; off-preset combos → `.custom`.
    static func matching(_ recurrence: Recurrence?) -> RecurrencePreset {
        guard let recurrence else { return .none }
        switch (recurrence.frequency, recurrence.interval) {
        case (.daily, 1): return .daily
        case (.weekly, 1): return .weekly
        case (.weekly, 2): return .everyTwoWeeks
        case (.monthly, 1): return .monthly
        case (.yearly, 1): return .yearly
        default: return .custom
        }
    }
}
