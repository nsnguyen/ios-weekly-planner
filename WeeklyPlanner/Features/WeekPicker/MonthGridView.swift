import SwiftUI

/// One month section inside `WeekPickerSheet`'s scroll body. Renders a
/// centered handwritten "May 2026"-style title, a Monday-first weekday
/// header row, and a stack of `WeekRowView`s (Phase 31 #33 #34).
///
/// Kept as its own struct (rather than inlined into the sheet) so the sheet
/// stays readable and so the month section can be previewed in isolation
/// once Phase 09 has its full preview suite.
struct MonthGridView: View {
    /// Phase 31 (34) presentation contract — the month title is centered.
    /// Unit-tested in `MonthGridViewTests.testTitleCentered`; the body
    /// consumes it via `frameAlignment`.
    static let titleAlignment: TextAlignment = .center

    /// Phase 31 (33) presentation contract — Monday-first weekday header,
    /// weekends included. Two letters (vs. the JS mock's single letter)
    /// because the single-letter form repeats T and S and reads as a typo.
    /// Unit-tested in `MonthGridViewTests.testWeekdayHeaderPresent`.
    static let weekdaySymbols = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    /// The month to render. The view reads `title` for the header row and
    /// hands each `PickerWeek` off to a `WeekRowView`.
    let month: PickerMonth

    /// The picker's currently-selected week offset. Forwarded to each row
    /// so it can light up its blue selection wash.
    let selectedWeekOffset: Int

    /// Tap handler forwarded to each `WeekRowView`. Invoked with the tapped
    /// row's `week.offset`.
    var onPick: (Int) -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.vertical, 4)

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

    /// "May 2026" handwritten title, centered across the full row width
    /// (Phase 31 #34 — was left-aligned with a trailing rule).
    private var header: some View {
        Text(month.title)
            .font(font.font(at: 18, weight: .bold))
            .foregroundStyle(theme.ink)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .padding(.horizontal, 2)
    }

    /// Maps the testable `TextAlignment` contract onto the frame alignment
    /// the header actually uses.
    private var frameAlignment: Alignment {
        switch Self.titleAlignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    /// Seven Monday-first weekday labels above the month's rows (Phase 31
    /// #33). Spacing/padding mirror `WeekRowView`'s day cells exactly so the
    /// columns line up: HStack(spacing: 3) + 14pt horizontal padding.
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
