import SwiftUI

/// One Mon-Sun row inside the week picker. Renders the `W##` label in a
/// fixed-width leading column and then seven equal-width day cells.
///
/// Three visual states layered onto the same row:
/// - **Selected**: 12% blue-ink wash behind the row, week-number switches to
///   `theme.blueInk`.
/// - **Contains today, not selected**: a 3pt-wide red vertical bar pinned to
///   the leading edge.
/// - **Today's cell**: a 24pt red circle behind the day number, with white
///   day text on top.
///
/// Tapping anywhere on the row fires `onPick(week.offset)` — the sheet then
/// pushes that offset back to `RootView` via `WeekPickerSheet.onPick` and
/// closes itself.
struct WeekRowView: View {
    /// The week to render. Carries the 7-day span and the `containsToday` /
    /// `weekNumber` metadata used for styling.
    let week: PickerWeek

    /// True when this row matches the picker's `selectedWeekOffset`. Drives
    /// the blue-wash background and the blue week-number color.
    let isSelected: Bool

    /// Tap handler. Invoked with the row's `week.offset` so the parent can
    /// `setWeek(_:)` on `PageFlipController` and dismiss the sheet.
    var onPick: (Int) -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        Button {
            onPick(week.offset)
        } label: {
            HStack(spacing: 3) {
                weekNumberLabel
                ForEach(week.days) { day in
                    dayCell(day)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 14)
            .background(rowBackground)
            .overlay(alignment: .leading) {
                if week.containsToday, !isSelected {
                    Rectangle()
                        .fill(theme.redInk)
                        .opacity(0.7)
                        .frame(width: 3, height: 28)
                        .cornerRadius(2)
                        .padding(.leading, 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIDs.weekpickerWeekRow(week.offset))
        .accessibilityLabel("Week \(week.weekNumber)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Subviews

    /// Fixed-width `W##` chip on the leading edge of the row. Picks up the
    /// blue ink when the row is selected, ink3 otherwise.
    private var weekNumberLabel: some View {
        Text("W\(week.weekNumber)")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(isSelected ? theme.blueInk : theme.ink3)
            .frame(width: 28, alignment: .center)
    }

    /// One day cell. Today gets the red filled circle behind the day number
    /// and white text on top; other days inherit `ink` (in-month) or `ink3`
    /// (out-of-month) coloring.
    private func dayCell(_ day: PickerDay) -> some View {
        ZStack {
            if day.isToday {
                Circle()
                    .fill(theme.redInk)
                    .frame(width: 24, height: 24)
            }
            Text("\(day.dayNumber)")
                .font(font.font(at: 17, weight: day.isToday ? .bold : .medium))
                .foregroundStyle(dayColor(day))
        }
        .frame(height: 28)
    }

    /// Day-number color: white over the red today disc, full ink for
    /// in-month days, ink3 for the leading/trailing out-of-month days.
    private func dayColor(_ day: PickerDay) -> Color {
        if day.isToday {
            return .white
        }
        return day.isInDisplayedMonth ? theme.ink : theme.ink3
    }

    /// Faint blue wash behind the row when selected. Clear otherwise so the
    /// sheet's gradient shows through.
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isSelected ? theme.blueInk.opacity(0.12) : Color.clear)
    }
}
