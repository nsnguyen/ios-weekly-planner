import SwiftUI

/// One Mon-Sun row inside the week picker. Renders seven equal-width day
/// cells (the leading `W##` ISO week-number column was removed in Phase 31
/// #33 — the columns now line up with `MonthGridView`'s weekday header).
///
/// Three visual states layered onto the same row:
/// - **Selected**: 12% blue-ink wash behind the row.
/// - **Contains today, not selected**: a 3pt-wide red vertical bar pinned to
///   the leading edge.
/// - **Today's cell**: a 24pt red circle behind the day number, with white
///   day text on top.
///
/// Tapping anywhere on the row fires `onPick(week.offset)` — the sheet then
/// pushes that offset back to `RootView` via `WeekPickerSheet.onPick` and
/// closes itself.
struct WeekRowView: View {
    /// Phase 31 (33) presentation contract — the leading "W##" ISO
    /// week-number column was removed; rows are seven full-width day cells.
    /// `PickerWeek.weekNumber` stays in the model (the removal is
    /// presentation-only). Unit-tested in
    /// `MonthGridViewTests.testNoWeekNumberRendered`.
    static let showsWeekNumberColumn = false

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
        .accessibilityLabel(Self.accessibilityLabel(for: week))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Accessibility

    /// Date-based VoiceOver label ("Week of May 11") — replaces the old
    /// "Week 21" ISO-number label, which no longer matches anything visible
    /// (Phase 31 #33).
    static func accessibilityLabel(for week: PickerWeek) -> String {
        guard let monday = week.days.first?.date else { return "Week" }
        return "Week of \(mondayFormatter.string(from: monday))"
    }

    /// "May 11" style. POSIX-locale so the label doesn't drift across
    /// devices; shared across all rows.
    private static let mondayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - Subviews

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
