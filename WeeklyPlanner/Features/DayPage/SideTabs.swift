import SwiftUI

/// Vertical column of seven `SideTab` views that sits alongside the Day page
/// and lets the user jump straight to any weekday by tapping its pastel tab.
/// Selection is driven by `selectedIdx`; the optional `todayIdx` adds a red
/// dot to whichever tab corresponds to the real-world today (or to nothing if
/// today is outside the displayed week).
///
/// The column reserves a fixed `Spacing.sideTabSelectedWidth` of horizontal
/// space so that growing/shrinking the selected tab between 22pt and 28pt
/// doesn't reflow neighbouring content. A 30pt top inset matches the mock and
/// lines the first tab up just below the book chrome.
struct SideTabs: View {
    /// The seven days of the displayed week, Monday-first. Index in this
    /// array must match `WeekDay.idx` (0...6).
    let weekDays: [WeekDay]

    /// Monday-based index of the currently focused day, `0...6`.
    let selectedIdx: Int

    /// Monday-based index of today, if today happens to fall inside
    /// `weekDays`. `nil` for any other week offset.
    let todayIdx: Int?

    /// Invoked with the tapped weekday's index. Parent decides whether to
    /// drive a page flip.
    var onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 4) {
            ForEach(weekDays, id: \.idx) { day in
                SideTab(idx: day.idx,
                        weekdayShort: day.weekdayShort,
                        weekdayLong: day.weekdayLong,
                        isSelected: day.idx == selectedIdx,
                        isToday: day.idx == todayIdx)
                {
                    onSelect(day.idx)
                }
            }
        }
        .padding(.top, 30)
        .frame(width: Spacing.sideTabSelectedWidth, alignment: .trailing)
    }
}

// MARK: - Previews

#Preview("SideTabs · Saturday selected & today") {
    let anchor: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16 // Saturday May 16, 2026 — the standard preview anchor
        components.hour = 12
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }()
    let days = WeekMath.weekDays(forOffset: 0, today: anchor)

    return ZStack(alignment: .topTrailing) {
        BookCover()
        SideTabs(weekDays: days,
                 selectedIdx: 5,
                 todayIdx: 5,
                 onSelect: { _ in })
            .padding(.trailing, 12)
            .padding(.top, 40)
    }
    .paperTheme(.cream)
}
