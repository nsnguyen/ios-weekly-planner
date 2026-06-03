import SwiftUI

/// Footer row pinned to the bottom of every page-flip surface. Holds two
/// labelled chevron buttons — `Last day` / `Next day` (or `Last week` /
/// `Next week` depending on the active spread) — with a quiet uppercase
/// `SWIPE ‹ ›` hint centered between them.
///
/// All chrome is theme-aware via `theme.chromeText`: the labels and chevrons
/// share the same tint, and the swipe hint is rendered at 40% alpha so it
/// reads as a passive affordance rather than a control.
///
/// Tap behavior is delegated to `onPrev` / `onNext` callbacks; this primitive
/// has no opinion about whether the parent does an instant offset bump or a
/// full page-flip animation. The composite at the call site decides.
struct BookBottomControls: View {
    /// Label for the leading-direction button — `"Last day"` in Day view,
    /// `"Last week"` in Week view. The caller chooses the wording.
    let prevLabel: String

    /// Label for the trailing-direction button — `"Next day"` in Day view,
    /// `"Next week"` in Week view.
    let nextLabel: String

    /// Invoked when the user taps the leading button.
    var onPrev: () -> Void

    /// Invoked when the user taps the trailing button.
    var onNext: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            prevButton
            Spacer()
            swipeHint
            Spacer()
            nextButton
        }
        .padding(EdgeInsets(top: 8, leading: 26, bottom: 14, trailing: 26))
    }

    /// Leading-direction button: chevron-left glyph only. Phase 29 (10) drops
    /// the spelled-out adjacent-page label; `prevLabel` is retained purely as
    /// the VoiceOver label so assistive tech still announces "Last day"/"Last
    /// week". A 10×8 hit-area inset keeps the tap target comfortable now that
    /// the text no longer contributes width.
    private var prevButton: some View {
        Button(action: onPrev) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(theme.chromeText)
                .contentShape(Rectangle().inset(by: -10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(prevLabel)
    }

    /// Trailing-direction button: chevron-right glyph only. See `prevButton`.
    private var nextButton: some View {
        Button(action: onNext) {
            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(theme.chromeText)
                .contentShape(Rectangle().inset(by: -10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nextLabel)
    }

    /// Centered uppercase hint reminding the user that horizontal swipes also
    /// advance the page. Rendered at 40% alpha and 1pt letter-spacing.
    private var swipeHint: some View {
        Text("SWIPE ‹ ›")
            .font(.system(size: 10, weight: .regular))
            .tracking(1)
            .foregroundStyle(theme.chromeText.opacity(0.4))
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("BookBottomControls · day · cream") {
    ZStack {
        BookCover()
        VStack {
            Spacer()
            BookBottomControls(prevLabel: "Last day",
                               nextLabel: "Next day",
                               onPrev: {},
                               onNext: {})
        }
    }
    .paperTheme(.cream)
}

#Preview("BookBottomControls · week · midnight") {
    ZStack {
        BookCover()
        VStack {
            Spacer()
            BookBottomControls(prevLabel: "Last week",
                               nextLabel: "Next week",
                               onPrev: {},
                               onNext: {})
        }
    }
    .paperTheme(.midnight)
}
