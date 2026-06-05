import Foundation

/// Expands the app's simple recurrence subset into concrete occurrence
/// dates inside a window. Used for display, reminder bounding, and tests.
/// The EventKit mirror still carries the real `EKRecurrenceRule` — this
/// expander exists so display works without Calendar access (see the
/// Phase 35 plan's declared deviation).
enum OccurrenceExpander {
    /// Occurrence starts of a series intersecting `window`, skipping
    /// `excluding` (single-occurrence deletes), capped at `limit`
    /// iterations as a runaway backstop.
    static func occurrenceStarts(seriesStart: Date,
                                 recurrence: Recurrence,
                                 in window: Range<Date>,
                                 excluding excluded: [Date] = [],
                                 calendar: Calendar,
                                 limit: Int = 400) -> [Date]
    {
        let component: Calendar.Component = switch recurrence.frequency {
        case .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        case .yearly: .year
        }

        // Inclusive end-of-day for `.onDate` (EKRecurrenceEnd(end:) keeps
        // occurrences ON the end day).
        var endCutoff: Date?
        if case let .onDate(endDate) = recurrence.end {
            let startOfEndDay = calendar.startOfDay(for: endDate)
            endCutoff = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfEndDay)
        }

        var result: [Date] = []
        var current = seriesStart
        var index = 0

        while index < limit {
            if case let .afterCount(count) = recurrence.end, index >= count { break }
            if let endCutoff, current > endCutoff { break }
            if current >= window.upperBound { break }

            if current >= window.lowerBound,
               !excluded.contains(where: { abs($0.timeIntervalSince(current)) < 1 })
            {
                result.append(current)
            }

            index += 1
            guard let next = calendar.date(byAdding: component,
                                           value: recurrence.interval,
                                           to: current) else { break }
            current = next
        }
        return result
    }
}
