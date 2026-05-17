import SwiftUI

/// The leather-book chrome that wraps every paper page. Stacks the top bar,
/// the active page content, and the bottom flip controls into a single
/// vertical column laid out over a full-bleed `BookCover` background.
///
/// `RootView` mounts a `BookContainer` and supplies the `content` closure
/// (today: a `DayPageView`; Group T will swap in a Day-or-Week chooser).
/// Navigation state — current week, paper view, picker open flag — lives in
/// the parent and is fed in through bindings and callbacks; the container is
/// otherwise stateless.
///
/// Layout:
/// - `ZStack(alignment: .top)` with `BookCover()` as the background.
/// - `VStack(spacing: 0)` with `BookTopBar`, then the page `content()` filling
///   the remaining space, then `BookBottomControls`.
///
/// The bottom controls' chevrons fan out to `onPrevDay` / `onNextDay` in Day
/// view and `onPrevWeek` / `onNextWeek` in Week view — the container picks
/// the right pair based on `paperView`. Labels (`"Last day"` vs `"Last
/// week"`) flip in lockstep.
struct BookContainer<Content: View>: View {
    /// Two-way binding to the active spread. Forwarded to `BookTopBar` and
    /// used here to pick the bottom-controls labels and route the prev/next
    /// callbacks to the right day-vs-week handler.
    @Binding var paperView: PaperView

    /// Header metadata for the visible week. Forwarded to `BookTopBar`.
    let weekMeta: WeekMeta

    /// True when the user is on the present day of the current week. Drives
    /// the visibility of the "Today" shortcut pill in the top bar.
    let isOnTodayPage: Bool

    /// True while the week-picker overlay is open. Drives the chevron
    /// rotation on `DateRangePill`.
    let isPickerOpen: Bool

    /// Forwarded to the trailing `AIButton`.
    var onOpenAI: () -> Void

    /// Forwarded to the `DateRangePill` tap target.
    var onOpenPicker: () -> Void

    /// Forwarded to the `TodayPill`.
    var onJumpToday: () -> Void

    /// Invoked when the user steps back by a week (top-bar chevron in Day or
    /// Week view, or the bottom-controls chevron in Week view).
    var onPrevWeek: () -> Void

    /// Invoked when the user steps forward by a week.
    var onNextWeek: () -> Void

    /// Invoked when the user steps back by a day (bottom-controls chevron in
    /// Day view).
    var onPrevDay: () -> Void

    /// Invoked when the user steps forward by a day.
    var onNextDay: () -> Void

    /// The page content rendered between the top bar and the bottom controls.
    /// Typically a `DayPageView` (or, after Group T, a `WeekPageView`).
    @ViewBuilder let content: () -> Content

    @Environment(\.paperTheme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            BookCover()

            VStack(spacing: 0) {
                BookTopBar(weekMeta: weekMeta,
                           paperView: $paperView,
                           isOnTodayPage: isOnTodayPage,
                           isPickerOpen: isPickerOpen,
                           onOpenAI: onOpenAI,
                           onOpenPicker: onOpenPicker,
                           onJumpToday: onJumpToday,
                           onPrevWeek: onPrevWeek,
                           onNextWeek: onNextWeek)

                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                BookBottomControls(prevLabel: prevLabel,
                                   nextLabel: nextLabel,
                                   onPrev: onPrev,
                                   onNext: onNext)
            }
        }
    }

    // MARK: - Bottom-controls plumbing

    /// `"Last day"` in Day view, `"Last week"` in Week view.
    private var prevLabel: String {
        paperView == .day ? "Last day" : "Last week"
    }

    /// `"Next day"` in Day view, `"Next week"` in Week view.
    private var nextLabel: String {
        paperView == .day ? "Next day" : "Next week"
    }

    /// Routes the bottom-controls "previous" tap to the correct callback for
    /// the active spread.
    private var onPrev: () -> Void {
        paperView == .day ? onPrevDay : onPrevWeek
    }

    /// Routes the bottom-controls "next" tap to the correct callback for the
    /// active spread.
    private var onNext: () -> Void {
        paperView == .day ? onNextDay : onNextWeek
    }
}

// MARK: - Previews

#Preview("BookContainer · cream · day view") {
    BookContainerPreviewHost(theme: .cream)
}

#Preview("BookContainer · midnight · day view") {
    BookContainerPreviewHost(theme: .midnight)
}

/// Preview host that wires bindings and renders a placeholder rectangle in
/// the content slot. Real previews mount this from `DayPageView.swift` once
/// the wiring is complete.
private struct BookContainerPreviewHost: View {
    let theme: PaperTheme

    @State private var paperView: PaperView = .day

    var body: some View {
        let weekMeta = WeekMath.weekMeta(forOffset: 0, today: Date())
        BookContainer(paperView: $paperView,
                      weekMeta: weekMeta,
                      isOnTodayPage: true,
                      isPickerOpen: false,
                      onOpenAI: {},
                      onOpenPicker: {},
                      onJumpToday: {},
                      onPrevWeek: {},
                      onNextWeek: {},
                      onPrevDay: {},
                      onNextDay: {},
                      content: { Color.clear })
            .paperTheme(theme)
    }
}
