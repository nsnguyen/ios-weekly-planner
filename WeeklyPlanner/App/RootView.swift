import SwiftUI

/// The root scene the user lands on when the app launches. Layers `BookCover`
/// behind a `DayPageView` for the current day. The Day page handles the
/// inner paper chrome (surface, grain, ruled lines, red margin, hole punches,
/// page-number footer) and the real content (header + events + inbox block
/// or empty-state hint).
///
/// Top / bottom padding clears the eventual top bar (Phase 09) and tab bar
/// (Phase 10) — both spaces are still empty today, but the Day page is
/// already sized to fit between them so swapping in the real chrome won't
/// reflow content.
///
/// Side tabs, week picker, page-flip gestures, and tab bar arrive in
/// Phases 08–10; do not add them here.
struct RootView: View {
    var body: some View {
        let today = Date()
        let days = WeekMath.weekDays(forOffset: 0, today: today)
        let todayIdx = WeekMath.todayIndex(in: days, for: today) ?? 0

        ZStack {
            BookCover()

            DayPageView(weekOffset: 0, dayIdx: todayIdx)
                .padding(.top, Spacing.bookTopBarTopPadding)
                .padding(.bottom, Spacing.tabBarHeight + Spacing.tabBarBottomSafeArea)
        }
    }
}

#Preview {
    RootView()
        .environment(\.eventStore, StubEventStore())
        .environment(\.inboxStore, StubInboxStore())
}
