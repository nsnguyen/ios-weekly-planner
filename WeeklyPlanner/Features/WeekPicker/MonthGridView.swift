import SwiftUI

/// One month section inside `WeekPickerSheet`'s scroll body. Renders a
/// handwritten "May 2026"-style title above a stack of `WeekRowView`s.
///
/// Kept as its own struct (rather than inlined into the sheet) so the sheet
/// stays readable and so the month section can be previewed in isolation
/// once Phase 09 has its full preview suite.
struct MonthGridView: View {
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

            ForEach(month.weeks) { week in
                WeekRowView(week: week,
                            isSelected: week.offset == selectedWeekOffset,
                            onPick: onPick)
                    .id(week.id)
            }
        }
        .padding(.bottom, 8)
    }

    /// "May 2026" handwritten title plus a hair-thin rule that fills the
    /// remaining row width. Mirrors the JS mock's `borderTop` rule trick.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(month.title)
                .font(font.font(at: 18, weight: .bold))
                .foregroundStyle(theme.ink)
                .lineLimit(1)

            Rectangle()
                .fill(theme.rule)
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 2)
    }
}
