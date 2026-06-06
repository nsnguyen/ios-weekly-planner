import SwiftUI

/// The flip-aware Week page surface. Wraps `WeekPageView` in a
/// `PageFlipContainer` so week-to-week navigation gets the same 3D page-flip
/// animation (and horizontal-swipe gesture) as the Day page — the Week view's
/// counterpart to `DayPageView`.
///
/// Like `DayPageView`, this does **not** own the `PageFlipController` —
/// `AppShell` does, and passes it in so the top bar's week chevrons, the
/// bottom controls, and this surface all share one source of truth.
///
/// ## Why this is safe now (Phase 27 → week-flip parity)
///
/// Originally the Week view rendered `WeekPageView` directly, with no
/// `PageFlipContainer`. The week chevrons called `flipWeek()`, which set
/// `controller.target` — but nothing in the week path ever called `commit()`,
/// so `isFlipping` stranded permanently and froze all navigation. The fix
/// gave the Week view a real flip container (this type) **and**
/// `PageFlipController` an `autoCommitDelay` fallback that force-commits any
/// un-committed flip. So even if a tree rebuild ever drops the view-driven
/// `commit()`, the controller resolves the flip itself — the freeze can't
/// recur. See `PageFlipController` and `docs/phases/phase-27-week-view-stability.md`.
struct WeekFlipView: View {
    /// Shared controller injected by `AppShell`. Drives this surface's
    /// swipe gesture and the top bar / bottom-control week chevrons.
    let controller: PageFlipController

    /// Construct a `WeekFlipView` over the supplied (shared) controller.
    init(controller: PageFlipController) {
        self.controller = controller
    }

    var body: some View {
        PageFlipContainer(controller: controller) { coord in
            // Only the week offset matters for the week spread; the day index
            // rides along in `coord` (preserved by `flipWeek`) and is ignored
            // here. The container applies `.id(coord)` so the week's view
            // model reloads its events whenever the offset changes — which is
            // also what makes the week picker show the correct week's events
            // (Phase 27 / suggestion 22), replacing the earlier manual `.id`.
            WeekPageView(weekOffset: coord.week)
        }
        .horizontalSwipe { direction in
            // Mirror DayPageView's guard: yield to an active sticky-note or
            // annotation drag (no annotation layer on week today, but parity
            // with the day path is safe if one is ever added).
            guard !controller.stickyDragActive, !controller.annotationDragActive else { return }
            controller.flipWeek(direction: direction)
        }
    }
}

// MARK: - Previews

#Preview("WeekFlipView · Today (stub stores)") {
    let controller = PageFlipController(current: PageCoordinate(week: 0, day: 2))
    return ZStack {
        BookCover()
        WeekFlipView(controller: controller)
            .padding(.top, Spacing.bookTopBarTopPadding)
            .padding(.bottom, Spacing.tabBarHeight + Spacing.tabBarBottomSafeArea)
    }
    .environment(\.eventStore, StubEventStore())
    .environment(\.taskStore, StubTaskStore())
    .environment(\.inboxStore, StubInboxStore())
    .paperTheme(.cream)
}
