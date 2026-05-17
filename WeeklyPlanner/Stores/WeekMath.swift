import Foundation

/// Pure functions for week / day math. Everything is Monday-based by default
/// (`weekStartsOnMonday == true` in `UserSettings`); pass a Sunday-start
/// calendar to switch.
///
/// All inputs are passed in explicitly so this is unit-testable without
/// touching `Date()` directly.
enum WeekMath {
    /// Returns 7 `WeekDay` values, Monday-first, for the week containing
    /// `today` shifted by `forOffset` weeks.
    static func weekDays(forOffset offset: Int,
                         calendar: Calendar = mondayCalendar(),
                         today: Date) -> [WeekDay]
    {
        let monday = mondayOfWeek(containing: today, offsetBy: offset, calendar: calendar)
        return (0 ..< 7).compactMap { idx -> WeekDay? in
            guard let date = calendar.date(byAdding: .day, value: idx, to: monday) else { return nil }
            let comps = calendar.dateComponents([.day, .month, .year], from: date)
            return WeekDay(idx: idx,
                           offset: offset,
                           date: date,
                           weekdayShort: weekdayShortFormatter.string(from: date),
                           weekdayLong: weekdayLongFormatter.string(from: date),
                           weekdayInitial: weekdayInitial(for: idx),
                           dayNumber: comps.day ?? 0,
                           monthShort: monthShortFormatter.string(from: date),
                           year: comps.year ?? 0)
        }
    }

    /// Header metadata for a week.
    static func weekMeta(forOffset offset: Int,
                         today: Date,
                         calendar: Calendar = mondayCalendar()) -> WeekMeta
    {
        let monday = mondayOfWeek(containing: today, offsetBy: offset, calendar: calendar)
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
        let weekNumber = calendar.component(.weekOfYear, from: monday)
        let isCurrent = offset == 0

        return WeekMeta(offset: offset,
                        weekNumber: weekNumber,
                        range: rangeString(from: monday, to: sunday, calendar: calendar),
                        monthFull: monthFullFormatter.string(from: monday),
                        isCurrent: isCurrent)
    }

    /// Index of `today` inside `week`, or `nil` if `today` is outside the
    /// range covered by those seven days.
    static func todayIndex(in week: [WeekDay],
                           for today: Date,
                           calendar: Calendar = mondayCalendar()) -> Int?
    {
        let day = calendar.startOfDay(for: today)
        return week.firstIndex { calendar.isDate($0.date, inSameDayAs: day) }
    }

    // MARK: - Internals

    /// Calendar configured to start weeks on Monday. ISO 8601 in spirit.
    static func mondayCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    /// Calendar configured to start weeks on Sunday — for users who toggle
    /// `weekStartsOnMonday = false`.
    static func sundayCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Sunday
        return cal
    }

    private static func mondayOfWeek(containing date: Date, offsetBy weeks: Int, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        // Monday=2 in Gregorian; convert to a "days since Monday" delta.
        let daysSinceMonday: Int = if calendar.firstWeekday == 2 {
            (weekday + 5) % 7
        } else {
            (weekday + 5) % 7
        }
        let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay) ?? startOfDay
        return calendar.date(byAdding: .day, value: weeks * 7, to: thisMonday) ?? thisMonday
    }

    /// `"May 11 – 17"` for same-month, `"May 30 – Jun 5"` for cross-month.
    private static func rangeString(from start: Date, to end: Date, calendar: Calendar) -> String {
        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)
        let startDay = calendar.component(.day, from: start)
        let endDay = calendar.component(.day, from: end)

        let startMonthShort = monthShortFormatter.string(from: start)

        if startMonth == endMonth {
            return "\(startMonthShort) \(startDay) – \(endDay)"
        }
        let endMonthShort = monthShortFormatter.string(from: end)
        return "\(startMonthShort) \(startDay) – \(endMonthShort) \(endDay)"
    }

    private static func weekdayInitial(for idx: Int) -> String {
        // Monday-based: M T W T F S S
        ["M", "T", "W", "T", "F", "S", "S"][idx]
    }

    // MARK: - Formatters

    private static let weekdayShortFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    private static let weekdayLongFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    private static let monthShortFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    private static let monthFullFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
}
