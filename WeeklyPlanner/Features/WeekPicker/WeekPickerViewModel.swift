import Foundation
import Observation

/// One calendar month rendered inside the week picker. The picker mounts a
/// ±24-month window of these in a vertical scroll — the focus month plus
/// `WeekPickerViewModel.monthWindowRadius` on either side (Phase 31 #36).
///
/// Identified by its `"yyyy-MM"` key so `ForEach` over `[PickerMonth]` keeps
/// stable identity when the focus week changes.
struct PickerMonth: Equatable, Identifiable {
    /// `"yyyy-MM"` — stable across rebuilds for the same calendar month.
    let id: String
    let year: Int
    /// 1-based (1 = January, 12 = December).
    let month: Int
    /// `"May 2026"` — pre-formatted display title for the month header row.
    let title: String
    /// Every week whose Monday or Sunday falls inside this month. Each entry
    /// carries the full Mon-Sun 7-day span so the row renderer can shade
    /// out-of-month leading / trailing days.
    let weeks: [PickerWeek]
}

/// One Mon-Sun week row inside a `PickerMonth`. The `offset` field is the
/// canonical handle used to drive the picker's selection — it is the same
/// offset the rest of the app uses against `PageFlipController` /
/// `WeekMath.weekDays(forOffset:today:)`.
struct PickerWeek: Equatable, Identifiable {
    /// `"\(offset)"` — the week offset is unique across the picker's view
    /// model, so it's both a sufficient ID and the value the row hands back
    /// when tapped.
    let id: String
    /// Offset relative to today's-week-Monday. `0` is the current week,
    /// `-1` the previous week, etc. Stable regardless of which month the
    /// week is being rendered under.
    let offset: Int
    /// ISO week number (1...53) of this week's Monday.
    let weekNumber: Int
    /// Seven days, Monday-first. Days outside `containingMonth` carry
    /// `isInDisplayedMonth = false`.
    let days: [PickerDay]
    /// True iff any day in the week is today (per the view model's
    /// `baseDate`). Drives the soft red leading bar in `WeekRowView`.
    let containsToday: Bool
}

/// One day cell inside a `PickerWeek` row. Carries everything the cell needs
/// to render itself — the day number, a flag for "this is part of the
/// month we're showing" (so out-of-month days dim), and a flag for "this is
/// today" (so the cell gets the red filled circle).
struct PickerDay: Equatable, Identifiable {
    /// `"yyyy-MM-dd"` — used for `ForEach` identity inside `WeekRowView`.
    let id: String
    /// 1...31 day-of-month.
    let dayNumber: Int
    /// Actual `Date` for this cell; used only by tests so far, but kept
    /// around so future "long press → quick event" flows have it.
    let date: Date
    /// True if `date` is inside the parent `PickerMonth`. False for leading
    /// days at the start of the first row or trailing days at the end of
    /// the last row of the month grid.
    let isInDisplayedMonth: Bool
    /// True if `date` is the same calendar day as the view model's
    /// `baseDate`. Exactly one day across the whole picker will be `true`.
    let isToday: Bool
}

/// View model for `WeekPickerSheet`. Pure math — given the user's `baseDate`
/// (typically `Date()`) and the currently-focused `focusWeekOffset` (the
/// offset that was selected when the picker opened), produces a ±24-month
/// window of `PickerMonth`s laid out around the focus month (Phase 31 #36).
///
/// `@MainActor @Observable` so the sheet view can re-render as
/// `selectedWeekOffset` changes (e.g., user taps a row, parent updates the
/// selection before dismissing). No async work happens here — everything is
/// computed eagerly in `init`.
@MainActor
@Observable
final class WeekPickerViewModel {
    /// Phase 31 (36): months built on either side of the focus month.
    /// ±24 (49 months total) — a generous fixed window chosen over lazy
    /// paging; revisit only if memory or scroll feel demands it.
    static let monthWindowRadius = 24

    /// The "now" date the picker treats as today. Tests inject a fixed date
    /// to avoid `Date()` flake; production callers pass `Date()`.
    let baseDate: Date

    /// The week offset the user was viewing when the picker opened. Drives
    /// the auto-scroll target and the initial `selectedWeekOffset`.
    let focusWeekOffset: Int

    /// The month window laid out around the focus month —
    /// `focusMonth - monthWindowRadius` through `focusMonth +
    /// monthWindowRadius` (49 months). Computed once in `init`; never
    /// mutated.
    var months: [PickerMonth] = []

    /// The week offset currently shown as selected. Starts equal to
    /// `focusWeekOffset`; the row tap handler in `WeekPickerSheet` keeps
    /// this in sync before dismissing.
    var selectedWeekOffset: Int

    /// Index into `months` of the month the nav bar currently displays.
    /// Starts at the focus month; nav chevrons step it, manual scrolling
    /// syncs it via `syncDisplayedMonth(toID:)`. Phase 31 (35).
    var displayedMonthIndex: Int = 0

    /// Designated initializer. Builds the month grid eagerly.
    ///
    /// - Parameters:
    ///   - baseDate: "Today" for the purposes of red-circle markers. Tests
    ///     pin this to May 16, 2026 to match the mock; production passes
    ///     `Date()`.
    ///   - focusWeekOffset: Week offset the picker should center on. Used
    ///     for both the month grid (focus month ± `monthWindowRadius`) and
    ///     the initial selection highlight.
    init(baseDate: Date = Date(), focusWeekOffset: Int) {
        self.baseDate = baseDate
        self.focusWeekOffset = focusWeekOffset
        selectedWeekOffset = focusWeekOffset
        months = Self.buildMonths(around: focusWeekOffset, baseDate: baseDate)

        // Start the displayed month on the focus month. Derived by id (not
        // by assuming the middle index) so a dropped month at the window
        // edge can't shift the anchor.
        let calendar = WeekMath.mondayCalendar()
        let todayMonday = Self.mondayOfWeek(containing: baseDate, calendar: calendar)
        let focusMonday = calendar.date(byAdding: .day, value: focusWeekOffset * 7, to: todayMonday) ?? todayMonday
        let comps = calendar.dateComponents([.year, .month], from: focusMonday)
        let focusID = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
        displayedMonthIndex = months.firstIndex { $0.id == focusID } ?? months.count / 2
    }

    // MARK: - Phase 31 (35): month/year navigation

    /// The month the nav bar shows. `nil` only if `months` is empty.
    var displayedMonth: PickerMonth? {
        months.indices.contains(displayedMonthIndex) ? months[displayedMonthIndex] : nil
    }

    /// True when a backward (older) step is possible.
    var canStepBackward: Bool { displayedMonthIndex > 0 }

    /// True when a forward (newer) step is possible.
    var canStepForward: Bool { displayedMonthIndex < months.count - 1 }

    /// Step the displayed month by `delta` months (±1 chevrons, ±12 year
    /// steppers), clamped to the built window.
    func stepMonth(by delta: Int) {
        guard !months.isEmpty else { return }
        displayedMonthIndex = min(max(displayedMonthIndex + delta, 0), months.count - 1)
    }

    /// Jump straight to a month/year. Returns the month on success, `nil`
    /// (and no state change) when the target is outside the built window.
    /// Never touches `selectedWeekOffset` — selection only changes on row tap.
    @discardableResult
    func jumpTo(year: Int, month: Int) -> PickerMonth? {
        guard let idx = months.firstIndex(where: { $0.year == year && $0.month == month }) else {
            return nil
        }
        displayedMonthIndex = idx
        return months[idx]
    }

    /// Keep `displayedMonthIndex` in sync while the user scrolls manually.
    /// Unknown ids (footer overscroll, transient nil) are ignored.
    func syncDisplayedMonth(toID id: String) {
        guard let idx = months.firstIndex(where: { $0.id == id }) else { return }
        displayedMonthIndex = idx
    }

    // MARK: - Month-grid construction

    /// Build `2 * monthWindowRadius + 1` `PickerMonth`s centered on the
    /// month containing the Monday of `baseDate + focusWeekOffset * 7 days`.
    ///
    /// - Parameters:
    ///   - focusWeekOffset: Offset that defines the focus month.
    ///   - baseDate: "Today" reference. Determines which week has offset 0
    ///     and which day is the red-circle today.
    /// - Returns: A 49-element array, oldest first.
    static func buildMonths(around focusWeekOffset: Int, baseDate: Date) -> [PickerMonth] {
        let calendar = WeekMath.mondayCalendar()
        let todayMonday = mondayOfWeek(containing: baseDate, calendar: calendar)
        let focusMonday = calendar.date(byAdding: .day, value: focusWeekOffset * 7, to: todayMonday) ?? todayMonday
        let focusComponents = calendar.dateComponents([.year, .month], from: focusMonday)
        guard let focusYear = focusComponents.year, let focusMonth = focusComponents.month else {
            return []
        }

        return (-monthWindowRadius ... monthWindowRadius).compactMap { delta -> PickerMonth? in
            guard let monthStart = calendar.date(from: DateComponents(year: focusYear,
                                                                      month: focusMonth + delta,
                                                                      day: 1))
            else {
                return nil
            }
            return buildMonth(containing: monthStart,
                              todayMonday: todayMonday,
                              baseDate: baseDate,
                              calendar: calendar)
        }
    }

    // MARK: - Internals

    /// Build a single `PickerMonth` for the calendar month that contains
    /// `monthStart`. Walks at most six Mon-Sun spans starting from the
    /// Monday on or before the month's 1st, keeping any span that includes
    /// at least one day inside the month.
    private static func buildMonth(containing monthStart: Date,
                                   todayMonday: Date,
                                   baseDate: Date,
                                   calendar: Calendar) -> PickerMonth?
    {
        let components = calendar.dateComponents([.year, .month], from: monthStart)
        guard let year = components.year, let month = components.month else { return nil }

        let monthFirstMonday = mondayOfWeek(containing: monthStart, calendar: calendar)

        var weeks: [PickerWeek] = []
        for weekIdx in 0 ..< 6 {
            guard let weekMonday = calendar.date(byAdding: .day, value: weekIdx * 7, to: monthFirstMonday) else {
                continue
            }
            let days: [PickerDay] = (0 ..< 7).compactMap { dayIdx -> PickerDay? in
                guard let dayDate = calendar.date(byAdding: .day, value: dayIdx, to: weekMonday) else {
                    return nil
                }
                let dayComps = calendar.dateComponents([.year, .month, .day], from: dayDate)
                let inMonth = (dayComps.month == month && dayComps.year == year)
                let dayId = String(format: "%04d-%02d-%02d",
                                   dayComps.year ?? 0,
                                   dayComps.month ?? 0,
                                   dayComps.day ?? 0)
                return PickerDay(id: dayId,
                                 dayNumber: dayComps.day ?? 0,
                                 date: dayDate,
                                 isInDisplayedMonth: inMonth,
                                 isToday: calendar.isDate(dayDate, inSameDayAs: baseDate))
            }
            // Drop spans that don't touch the month at all (can happen when
            // the focus month starts late in the week and we'd otherwise
            // generate a trailing all-out-of-month row).
            guard days.contains(where: \.isInDisplayedMonth) else { continue }

            let daysBetween = calendar.dateComponents([.day], from: todayMonday, to: weekMonday).day ?? 0
            let weekOffset = daysBetween / 7
            let weekNumber = calendar.component(.weekOfYear, from: weekMonday)
            let containsToday = days.contains(where: \.isToday)

            weeks.append(PickerWeek(id: "\(weekOffset)",
                                    offset: weekOffset,
                                    weekNumber: weekNumber,
                                    days: days,
                                    containsToday: containsToday))
        }

        return PickerMonth(id: String(format: "%04d-%02d", year, month),
                           year: year,
                           month: month,
                           title: titleFormatter.string(from: monthStart),
                           weeks: weeks)
    }

    /// Monday of the week containing `date`. Always returns a Monday at the
    /// start of day for the given calendar. Matches `WeekMath`'s internal
    /// helper, duplicated here because that one is private to `WeekMath`.
    private static func mondayOfWeek(containing date: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay) ?? startOfDay
    }

    /// `"May 2026"` style. POSIX-locale so the format doesn't drift across
    /// devices, and shared across all five months in the picker.
    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
