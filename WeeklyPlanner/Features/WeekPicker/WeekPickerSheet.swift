import SwiftUI

/// Drop-down week picker overlay. Sits above the book chrome whenever
/// `isOpen == true` and renders a 5-month mini grid the user can scroll
/// through and tap to jump to any week.
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

    // MARK: - Scroll body

    /// Vertical scroll containing the five months. Uses `ScrollViewReader`
    /// so the initial appearance can center the focused week.
    ///
    /// `ScrollView` is the outer view (standard SwiftUI pattern — putting
    /// `ScrollViewReader` outside means the frame modifier doesn't propagate
    /// through to the actual scrolling surface, which left the ScrollView
    /// sized to its content's natural height and broke the gesture). The
    /// `.frame(maxHeight: .infinity)` on the ScrollView is what the JS mock's
    /// `flex: 1, overflowY: 'auto'` does — claim the remaining vertical
    /// space inside the sheet VStack so content overflows and scrolls.
    /// `.layoutPriority(1)` reinforces this against the parent VStack's
    /// other (fixed-height) children.
    private var scrollBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.months) { month in
                        MonthGridView(month: month,
                                      selectedWeekOffset: viewModel.selectedWeekOffset,
                                      onPick: handlePick)
                    }

                    footer
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .padding(.bottom, 14)
                .onAppear {
                    // Defer one runloop tick so the VStack is laid out
                    // before we ask the proxy to scroll — otherwise the
                    // proxy can pick an offset based on stale row frames.
                    DispatchQueue.main.async {
                        proxy.scrollTo("\(initialWeekOffset)", anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1)
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
