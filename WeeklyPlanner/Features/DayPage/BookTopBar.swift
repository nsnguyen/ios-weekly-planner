import SwiftUI

/// The leather-chrome top bar that sits above every paper page. Composes the
/// six top-bar primitives shipped in Group P into the two-row layout from the
/// JS mock:
///
/// **Row 1** — baseline-aligned. Left cluster: an uppercase "THE PLANNER ·
/// WEEK N" eyebrow stacked over a horizontal `‹ DateRangePill ›` group.
/// A spacer pushes the trailing-edge `AIButton` to the far right.
///
/// **Row 2** — 6pt below Row 1. `DayWeekToggle` followed (only when the user
/// has navigated away from today) by a small `TodayPill` shortcut.
///
/// The bar reads `theme.chromeText` from `@Environment(\.paperTheme)` for the
/// eyebrow color. Every callback is forwarded to the parent (`RootView`) which
/// owns the actual navigation state — this view is purely chrome-and-layout.
///
/// Outer padding matches the mock exactly:
/// `top: 54 (statusbar/dynamic island clearance), leading: 26, trailing: 16,
/// bottom: 8`.
struct BookTopBar: View {
    /// Header metadata for the visible week. Drives the eyebrow's week-number
    /// suffix and the date range string rendered inside `DateRangePill`.
    let weekMeta: WeekMeta

    /// Two-way binding to the active spread (Day vs Week). Forwarded to
    /// `DayWeekToggle`; mutations flow back up to the parent.
    @Binding var paperView: PaperView

    /// True when the user is on the present day of the current week. Hides the
    /// "Today" shortcut pill, since it would be a no-op.
    let isOnTodayPage: Bool

    /// True while the week-picker overlay is open. Rotates the
    /// `DateRangePill` chevron 180° via animation.
    let isPickerOpen: Bool

    /// Invoked when the user taps the trailing `AIButton`. The parent shows
    /// the Apple Intelligence overlay (Phase 12).
    var onOpenAI: () -> Void

    /// Invoked when the user taps the `DateRangePill`. The parent toggles the
    /// week picker open / closed.
    var onOpenPicker: () -> Void

    /// Invoked when the user taps the `TodayPill`. The parent jumps back to
    /// the current week and today's weekday.
    var onJumpToday: () -> Void

    /// Invoked when the user taps the leading week chevron. The parent steps
    /// backward by one week (instant in Day view, flip in Week view).
    var onPrevWeek: () -> Void

    /// Invoked when the user taps the trailing week chevron. The parent steps
    /// forward by one week.
    var onNextWeek: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            topRow
            bottomRow
        }
        .padding(EdgeInsets(top: 54, leading: 26, bottom: 8, trailing: 16))
    }

    // MARK: - Rows

    /// Row 1: eyebrow + week-chevron cluster on the left, AI button on the
    /// trailing edge. Baseline-aligned so the date range pill and AI button
    /// share a common typographic baseline with the eyebrow above.
    private var topRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            leftCluster
            Spacer(minLength: 0)
            AIButton(accent: theme.blueInk, action: onOpenAI)
                .alignmentGuide(.lastTextBaseline) { dim in dim[.bottom] - 6 }
        }
    }

    /// Row 2: Day/Week segmented toggle plus the optional Today shortcut.
    private var bottomRow: some View {
        HStack(spacing: 6) {
            DayWeekToggle(selection: $paperView)

            if !isOnTodayPage {
                TodayPill(action: onJumpToday)
            }
        }
    }

    // MARK: - Top-row left cluster

    /// Stacks the uppercase "WEEK N" eyebrow over the chevron + date-range
    /// triplet. Slight negative inter-row spacing pulls the pill snug against
    /// the eyebrow to match the mock's `marginTop: -1`.
    private var leftCluster: some View {
        VStack(alignment: .leading, spacing: -1) {
            eyebrow

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                WeekChevronButton(direction: .prev, action: onPrevWeek)
                DateRangePill(rangeText: weekMeta.range,
                              chevronRotation: isPickerOpen ? 180 : 0,
                              action: onOpenPicker)
                WeekChevronButton(direction: .next, action: onNextWeek)
            }
        }
    }

    /// Uppercase tracked label above the date range, e.g.
    /// `"THE PLANNER · WEEK 20"`. Bold 10pt system, 1.6 letter-spacing, 65%
    /// opacity on `theme.chromeText` so the leather still shows through.
    private var eyebrow: some View {
        Text("THE PLANNER · WEEK \(weekMeta.weekNumber)")
            .font(.system(size: 10, weight: .bold))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(theme.chromeText.opacity(0.65))
    }
}

// MARK: - Previews

#Preview("BookTopBar · cream · current week") {
    BookTopBarPreviewHost(theme: .cream,
                          weekMeta: WeekMath.weekMeta(forOffset: 0, today: Date()),
                          isOnTodayPage: true)
}

#Preview("BookTopBar · kraft · past week (Today pill visible)") {
    BookTopBarPreviewHost(theme: .kraft,
                          weekMeta: WeekMath.weekMeta(forOffset: -2, today: Date()),
                          isOnTodayPage: false)
}

#Preview("BookTopBar · midnight · picker open") {
    BookTopBarPreviewHost(theme: .midnight,
                          weekMeta: WeekMath.weekMeta(forOffset: 0, today: Date()),
                          isOnTodayPage: true,
                          isPickerOpen: true)
}

/// Preview host that wires the `paperView` and `isPickerOpen` bindings to
/// local state so the toggle and chevron rotation can be exercised live in
/// the canvas.
private struct BookTopBarPreviewHost: View {
    let theme: PaperTheme
    let weekMeta: WeekMeta
    let isOnTodayPage: Bool
    var isPickerOpen: Bool = false

    @State private var paperView: PaperView = .day

    var body: some View {
        ZStack(alignment: .top) {
            BookCover()
            BookTopBar(weekMeta: weekMeta,
                       paperView: $paperView,
                       isOnTodayPage: isOnTodayPage,
                       isPickerOpen: isPickerOpen,
                       onOpenAI: {},
                       onOpenPicker: {},
                       onJumpToday: {},
                       onPrevWeek: {},
                       onNextWeek: {})
        }
        .paperTheme(theme)
    }
}
