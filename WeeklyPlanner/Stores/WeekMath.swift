import Foundation

/// User-selectable week start (Phase 36b). Raw value == `Calendar.firstWeekday`
/// (1 = Sunday … 7 = Saturday) so it threads straight into Calendar.
enum WeekStartDay: Int, CaseIterable, Codable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var displayName: String {
        switch self {
        case .sunday: "Sunday"
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        }
    }
}

/// Pure functions for week / day math. Weeks follow `preferredCalendar`
/// (seeded from `UserSettings.weekStart`) unless a caller passes an explicit
/// calendar.
///
/// All inputs are passed in explicitly so this is unit-testable without
/// touching `Date()` directly.
enum WeekMath {
    /// Returns 7 `WeekDay` values, week-start-first, for the week containing
    /// `today` shifted by `forOffset` weeks.
    static func weekDays(forOffset offset: Int,
                         calendar: Calendar = preferredCalendar,
                         today: Date) -> [WeekDay]
    {
        let weekStart = startOfWeek(containing: today, offsetBy: offset, calendar: calendar)
        return (0 ..< 7).compactMap { idx -> WeekDay? in
            guard let date = calendar.date(byAdding: .day, value: idx, to: weekStart) else { return nil }
            let comps = calendar.dateComponents([.day, .month, .year], from: date)
            return WeekDay(idx: idx,
                           offset: offset,
                           date: date,
                           weekdayShort: weekdayShortFormatter.string(from: date),
                           weekdayLong: weekdayLongFormatter.string(from: date),
                           weekdayInitial: weekdayInitial(for: idx, calendar: calendar),
                           dayNumber: comps.day ?? 0,
                           monthShort: monthShortFormatter.string(from: date),
                           year: comps.year ?? 0)
        }
    }

    /// Header metadata for a week.
    static func weekMeta(forOffset offset: Int,
                         today: Date,
                         calendar: Calendar = preferredCalendar) -> WeekMeta
    {
        let weekStart = startOfWeek(containing: today, offsetBy: offset, calendar: calendar)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let weekNumber = calendar.component(.weekOfYear, from: weekStart)
        let isCurrent = offset == 0

        return WeekMeta(offset: offset,
                        weekNumber: weekNumber,
                        range: rangeString(from: weekStart, to: weekEnd, calendar: calendar),
                        monthFull: monthFullFormatter.string(from: weekStart),
                        isCurrent: isCurrent)
    }

    /// Index of `today` inside `week`, or `nil` if `today` is outside the
    /// range covered by those seven days.
    static func todayIndex(in week: [WeekDay],
                           for today: Date,
                           calendar: Calendar = preferredCalendar) -> Int?
    {
        let day = calendar.startOfDay(for: today)
        return week.firstIndex { calendar.isDate($0.date, inSameDayAs: day) }
    }

    // MARK: - Internals

    /// Calendar for an arbitrary week start.
    static func calendar(startingOn day: WeekStartDay) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = day.rawValue
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    /// Calendar configured to start weeks on Monday. ISO 8601 in spirit.
    static func mondayCalendar() -> Calendar {
        calendar(startingOn: .monday)
    }

    /// Calendar configured to start weeks on Sunday.
    static func sundayCalendar() -> Calendar {
        calendar(startingOn: .sunday)
    }

    /// Process-wide week-start preference (Phase 36b). Seeded from
    /// `UserSettings.weekStart` in `WeeklyPlannerApp` before first layout
    /// and re-set by `AppShell` when the setting changes. Main-actor
    /// confined by convention (app shell writes; UI/store reads); tests
    /// that mutate it MUST reset to `mondayCalendar()` in tearDown.
    nonisolated(unsafe) static var preferredCalendar: Calendar = WeekMath.mondayCalendar()

    private static func startOfWeek(containing date: Date, offsetBy weeks: Int, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        // Days since the calendar's first weekday. For Monday-start
        // (firstWeekday == 2) this is the old `(weekday + 5) % 7`.
        let daysSinceStart = (weekday - calendar.firstWeekday + 7) % 7
        let weekStart = calendar.date(byAdding: .day, value: -daysSinceStart, to: startOfDay) ?? startOfDay
        return calendar.date(byAdding: .day, value: weeks * 7, to: weekStart) ?? weekStart
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

    /// Single-letter weekday initial for column `idx` of a week that
    /// starts on `calendar.firstWeekday`.
    static func weekdayInitial(for idx: Int, calendar: Calendar) -> String {
        // Calendar.weekday order: 1=Sun … 7=Sat.
        let base = ["S", "M", "T", "W", "T", "F", "S"]
        return base[(calendar.firstWeekday - 1 + idx) % 7]
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
