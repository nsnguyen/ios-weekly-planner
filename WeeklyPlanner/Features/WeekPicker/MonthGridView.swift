import SwiftUI

/// One month section inside `WeekPickerSheet`'s scroll body. Renders a
/// weekday header row that follows the configured week start, and a stack
/// of `WeekRowView`s (Phase 31 #33, Phase 36b).
///
/// The month/year title lives once, in the sheet's sticky nav bar
/// (`weekpickerNavTitle`). This grid does not repeat it (Phase 45 #76).
///
/// Kept as its own struct (rather than inlined into the sheet) so the sheet
/// stays readable and so the month section can be previewed in isolation
/// once Phase 09 has its full preview suite.
struct MonthGridView: View {
    /// Phase 31 (33) presentation contract — weekday header, weekends
    /// included. Two letters (vs. the single-letter form) because T and S
    /// would otherwise repeat and read as a typo, and because `ForEach`
    /// identity must be unique. Rotates with `WeekMath.preferredCalendar`
    /// (Phase 36b). Monday-start stays `Mo…Su`.
    /// Unit-tested in `MonthGridViewTests.testWeekdayHeaderPresent`.
    static var weekdaySymbols: [String] {
        weekdaySymbols(for: WeekMath.preferredCalendar)
    }

    /// Two-letter weekday labels for a week that starts on
    /// `calendar.firstWeekday`. Sunday-based order rotated into place.
    static func weekdaySymbols(for calendar: Calendar) -> [String] {
        let ordered = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        let start = (calendar.firstWeekday - 1 + 7) % 7
        return (0 ..< 7).map { ordered[(start + $0) % 7] }
    }

    /// The month to render. Each `PickerWeek` is handed to a `WeekRowView`.
    let month: PickerMonth

    /// The picker's currently-selected week offset. Forwarded to each row
    /// so it can light up its blue selection wash.
    let selectedWeekOffset: Int

    /// Tap handler forwarded to each `WeekRowView`. Invoked with the tapped
    /// row's `week.offset`.
    var onPick: (Int) -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            weekdayHeader

            ForEach(month.weeks) { week in
                WeekRowView(week: week,
                            isSelected: week.offset == selectedWeekOffset,
                            onPick: onPick)
                    .id(week.id)
            }
        }
        .padding(.bottom, 8)
    }

    /// Seven weekday labels above the month's rows (Phase 31 #33, rotated
    /// in Phase 36b). Spacing/padding mirror `WeekRowView`'s day cells
    /// exactly so the columns line up: HStack(spacing: 3) + 14pt horizontal
    /// padding.
    private var weekdayHeader: some View {
        HStack(spacing: 3) {
            ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(theme.ink3)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(EdgeInsets(top: 2, leading: 14, bottom: 4, trailing: 14))
    }
}
