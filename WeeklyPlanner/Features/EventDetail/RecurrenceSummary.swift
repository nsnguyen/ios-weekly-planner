import Foundation

/// Human-readable recurrence line for read mode: "Every week on Mon",
/// "Every 2 weeks on Mon", "Every day until Jun 30", "Every month, 5 times".
enum RecurrenceSummary {
    static func text(for recurrence: Recurrence,
                     seriesStart: Date,
                     calendar: Calendar = WeekMath.mondayCalendar()) -> String
    {
        var base: String = if recurrence.interval == 1 {
            "Every \(recurrence.frequency.unitName)"
        } else {
            "Every \(recurrence.interval) \(recurrence.frequency.unitName)s"
        }

        if recurrence.frequency == .weekly {
            base += " on \(weekdayShortFormatter.string(from: seriesStart))"
        }

        switch recurrence.end {
        case .never:
            return base
        case let .onDate(date):
            return "\(base) until \(monthDayFormatter.string(from: date))"
        case let .afterCount(count):
            return "\(base), \(count) times"
        }
    }

    private static let weekdayShortFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    private static let monthDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
}
