import EventKit
import Foundation

/// Lossless mapping between the app's simple `Recurrence` and
/// `EKRecurrenceRule`, for the supported subset. Anything fancier
/// (BYDAY sets, set positions, …) maps to `nil` and the event imports
/// as a single occurrence — a stated Phase 35 limit.
enum RecurrenceMapper {
    static func toEKRule(_ recurrence: Recurrence) -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency = switch recurrence.frequency {
        case .daily: .daily
        case .weekly: .weekly
        case .monthly: .monthly
        case .yearly: .yearly
        }
        let end: EKRecurrenceEnd? = switch recurrence.end {
        case .never: nil
        case let .onDate(date): EKRecurrenceEnd(end: date)
        case let .afterCount(count): EKRecurrenceEnd(occurrenceCount: count)
        }
        return EKRecurrenceRule(recurrenceWith: frequency,
                                interval: recurrence.interval,
                                end: end)
    }

    static func toRecurrence(_ rules: [EKRecurrenceRule]?) -> Recurrence? {
        guard let rule = rules?.first else { return nil }

        // Subset guard: at most the single anchor weekday on weekly rules,
        // and no other BY-components.
        guard (rule.daysOfTheWeek?.count ?? 0) <= 1,
              rule.daysOfTheMonth?.isEmpty ?? true,
              rule.daysOfTheYear?.isEmpty ?? true,
              rule.weeksOfTheYear?.isEmpty ?? true,
              rule.setPositions?.isEmpty ?? true
        else { return nil }
        if let months = rule.monthsOfTheYear, !months.isEmpty, rule.frequency != .yearly {
            return nil
        }
        if let days = rule.daysOfTheWeek, !days.isEmpty, rule.frequency != .weekly {
            return nil
        }

        let frequency: RecurrenceFrequency
        switch rule.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        @unknown default: return nil
        }

        let end: RecurrenceEnd
        if let ekEnd = rule.recurrenceEnd {
            if let date = ekEnd.endDate {
                end = .onDate(date)
            } else {
                end = .afterCount(ekEnd.occurrenceCount)
            }
        } else {
            end = .never
        }
        return Recurrence(frequency: frequency, interval: rule.interval, end: end)
    }
}
