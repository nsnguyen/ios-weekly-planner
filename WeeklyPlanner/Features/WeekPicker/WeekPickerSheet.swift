import SwiftUI

/// Drop-down week picker overlay. Sits above the book chrome whenever
/// `isOpen == true` and renders a ±24-month mini grid the user can scroll
/// through — or drive with the month/year nav bar (Phase 31 #35 #36) — and
/// tap to jump to any week.
///
/// Layout:
/// - A `ZStack` that renders nothing when closed.
/// - When open: a dark backdrop (tap to dismiss) plus a paper-toned sheet
///   inset 12pt on the sides, 100pt below the status bar, 16pt from the
///   bottom — matching the JS mock's geometry.
///
/// The view model is owned via `@State` so the picker can re-render
/// instantly when the user taps a different row before dismissing. The
/// parent owns the sheet's open/closed state via `isOpen` and the actual
/// week selection via `onPick`.
struct WeekPickerSheet: View {
    /// Two-way binding to the sheet's open state. Set to `false` by the
    /// backdrop tap, the Close button, and after `onPick` fires.
    @Binding var isOpen: Bool

    /// The week offset the picker should center on when it opens. Drives
    /// both the view model's focus month and the auto-scroll target.
    let initialWeekOffset: Int

    /// Invoked with the chosen week offset. The parent should `setWeek(_:)`
    /// on its `PageFlipController` and then close the sheet (the sheet
    /// also flips `isOpen` to `false` itself, but the parent is free to do
    /// extra work first — e.g., jumping to a specific day).
    var onPick: (Int) -> Void

    @State private var viewModel: WeekPickerViewModel

    /// Month id (`"yyyy-MM"`) the scroll body is anchored to, bound to
    /// `.scrollPosition(id:)`. Nav-bar buttons write it (programmatic
    /// scroll); manual scrolling writes it back and `syncDisplayedMonth`
    /// keeps the nav title in step. Phase 31 (35)(36).
    @State private var scrolledMonthID: String?

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Designated initializer. Constructs the view model eagerly so the
    /// sheet renders without a frame of empty content on first open.
    init(isOpen: Binding<Bool>,
         initialWeekOffset: Int,
         onPick: @escaping (Int) -> Void)
    {
        _isOpen = isOpen
        self.initialWeekOffset = initialWeekOffset
        self.onPick = onPick
        _viewModel = State(initialValue: WeekPickerViewModel(focusWeekOffset: initialWeekOffset))
    }

    var body: some View {
        ZStack {
            if isOpen {
                backdrop
                    .transition(.opacity)

                sheet
                    .transition(.asymmetric(insertion: .offset(y: -14).combined(with: .opacity),
                                            removal: .opacity))
            }
        }
        .animation(AnimationTokens.pickerDrop(reduced: reduceMotion), value: isOpen)
    }

    // MARK: - Backdrop

    /// Translucent dark scrim. Sized to fill its parent so taps anywhere
    /// outside the sheet dismiss it.
    private var backdrop: some View {
        Color(hex: "#0F0A06")
            .opacity(0.55)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                isOpen = false
            }
            .accessibilityLabel("Close week picker")
    }

    // MARK: - Sheet card

    /// The actual picker card. Inset from the screen edges per the mock,
    /// rounded 12pt, with a double-drop shadow so it reads as floating
    /// well above the book chrome.
    private var sheet: some View {
        VStack(spacing: 0) {
            header
            divider
            monthNavBar
            divider
            scrollBody
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(sheetBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.55), radius: 16, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 2)
        .padding(EdgeInsets(top: 100, leading: 12, bottom: 16, trailing: 12))
    }

    /// 160° linear gradient from `#FCF9EE` to `#F1EAD2`. The hex values are
    /// inlined from the spec — they are the same in every theme because the
    /// picker is always a cream sheet over the dark scrim.
    private var sheetBackground: some View {
        let points = CSSGradientAngle.unitPoints(degrees: 160)
        return LinearGradient(colors: [Color(hex: "#FCF9EE"), Color(hex: "#F1EAD2")],
                              startPoint: points.start,
                              endPoint: points.end)
    }

    // MARK: - Header

    /// Header strip: eyebrow + title on the left, Today/Close pill buttons
    /// on the right. Padding mirrors the JS mock exactly.
    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text("JUMP TO WEEK")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.ink2)

                Text("Pick a date")
                    .font(font.font(at: 22, weight: .regular))
                    .foregroundStyle(theme.ink)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                PaperPillButton(title: "Today", variant: .primary, size: .compact) {
                    onPick(0)
                    isOpen = false
                }
                PaperPillButton(title: "Close", variant: .secondary, size: .compact) {
                    isOpen = false
                }
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 10, trailing: 16))
    }

    /// 0.5pt rule under the header. Matches `border-bottom: 0.5px solid theme.rule`.
    private var divider: some View {
        Rectangle()
            .fill(theme.rule)
            .frame(height: 0.5)
    }

    // MARK: - Month/year navigation

    /// Explicit month/year navigation (Phase 31 #35): « / » step a year,
    /// ‹ / › step a month, the centered label names the displayed month.
    /// Not scroll-only anymore — but scrolling still works and keeps the
    /// label in sync via `scrolledMonthID`.
    private var monthNavBar: some View {
        HStack(spacing: 2) {
            navButton(systemName: "chevron.left.2",
                      id: AccessibilityIDs.weekpickerYearPrev,
                      label: "Previous year",
                      enabled: viewModel.canStepBackward) { step(-12) }
            navButton(systemName: "chevron.left",
                      id: AccessibilityIDs.weekpickerMonthPrev,
                      label: "Previous month",
                      enabled: viewModel.canStepBackward) { step(-1) }

            Text(viewModel.displayedMonth?.title ?? " ")
                .font(font.font(at: 16, weight: .bold))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier(AccessibilityIDs.weekpickerNavTitle)

            navButton(systemName: "chevron.right",
                      id: AccessibilityIDs.weekpickerMonthNext,
                      label: "Next month",
                      enabled: viewModel.canStepForward) { step(1) }
            navButton(systemName: "chevron.right.2",
                      id: AccessibilityIDs.weekpickerYearNext,
                      label: "Next year",
                      enabled: viewModel.canStepForward) { step(12) }
        }
        .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
        .background(Color(red: 250 / 255, green: 246 / 255, blue: 233 / 255).opacity(0.85))
    }

    /// One chevron button in the nav bar. 32pt square hit target, dimmed
    /// and disabled at a window edge.
    private func navButton(systemName: String,
                           id: String,
                           label: String,
                           enabled: Bool,
                           action: @escaping () -> Void) -> some View
    {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(enabled ? theme.ink2 : theme.ink3.opacity(0.4))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(id)
        .accessibilityLabel(label)
    }

    /// Step the displayed month and scroll the grid to it. ±1 from the
    /// month chevrons, ±12 from the year steppers; the view model clamps
    /// to the built window.
    private func step(_ deltaMonths: Int) {
        viewModel.stepMonth(by: deltaMonths)
        guard let id = viewModel.displayedMonth?.id else { return }
        if reduceMotion {
            scrolledMonthID = id
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                scrolledMonthID = id
            }
        }
    }

    // MARK: - Scroll body

    /// Vertical scroll containing the ±24-month window. `LazyVStack` keeps
    /// 49 month sections affordable; `.scrollTargetLayout()` +
    /// `.scrollPosition(id:)` give month-granular two-way scroll control
    /// (nav bar ↔ manual scrolling) and replace the old
    /// `ScrollViewReader` + deferred-`scrollTo` hack.
    ///
    /// The `.frame(maxHeight: .infinity)` + `.layoutPriority(1)` MUST stay
    /// directly on the `ScrollView` — that is the fix for the historical
    /// "picker scroll gesture dead" bug (the scroll surface otherwise sizes
    /// to its content's natural height and the gesture breaks). It is what
    /// the JS mock's `flex: 1, overflowY: 'auto'` does — claim the
    /// remaining vertical space inside the sheet VStack so content
    /// overflows and scrolls.
    private var scrollBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.months) { month in
                    MonthGridView(month: month,
                                  selectedWeekOffset: viewModel.selectedWeekOffset,
                                  onPick: handlePick)
                }

                footer
            }
            .scrollTargetLayout()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .scrollPosition(id: $scrolledMonthID, anchor: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1)
        .onAppear {
            // Re-anchor on the focus month every time the sheet opens
            // (replaces the old scrollTo-on-appear).
            scrolledMonthID = viewModel.displayedMonth?.id
        }
        .onChange(of: scrolledMonthID) { _, newID in
            guard let newID else { return }
            viewModel.syncDisplayedMonth(toID: newID)
        }
    }

    /// Italic handwritten footer line — purely decorative hint.
    private var footer: some View {
        Text("Tap any week to flip there.")
            .font(.custom("Cochin-Italic", size: 13))
            .foregroundStyle(theme.ink3)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 14)
            .padding(.top, 8)
    }

    // MARK: - Row tap handler

    /// Centralized row-tap handler so the same flow runs whether the tap
    /// comes from a `WeekRowView` or the Today pill: update the picker's
    /// selection (so the row briefly shows the blue wash before the sheet
    /// closes), notify the parent, and dismiss.
    private func handlePick(_ offset: Int) {
        viewModel.selectedWeekOffset = offset
        onPick(offset)
        isOpen = false
    }
}
