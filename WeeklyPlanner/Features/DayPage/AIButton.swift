import SwiftUI

/// Small 34×34 capsule button that opens the Apple Intelligence overlay from
/// the trailing edge of the planner's top bar. Renders a single SF Symbol
/// `sparkles` glyph tinted in the user's chosen accent color over a faint
/// translucent chrome background, so the button reads as "live AI" against
/// the dark leather cover behind it.
///
/// The control is theme-aware only for its semantic surroundings (the leather
/// cover provided by `BookCover`). The border and background tints are fixed
/// white-on-leather values — `Color.white.opacity(0.12)` and `0.06`
/// respectively — so the button reads identically in Cream, Kraft, and
/// Midnight themes. Only the sparkles glyph itself is colored, using the
/// `accent` parameter that defaults to `theme.blueInk`.
struct AIButton: View {
    /// Color of the sparkles glyph. Typically the user's selected accent color
    /// from Settings; callers that don't have one wired pass `theme.blueInk`.
    let accent: Color

    /// Invoked when the user taps the button. The parent shows the AI overlay
    /// (Phase 12); this primitive only emits the tap.
    var action: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.06), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Apple Intelligence")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Previews

#Preview("AIButton · accents over leather") {
    ZStack {
        BookCover()
        HStack(spacing: 16) {
            AIButton(accent: PaperTheme.cream.blueInk) {}
            AIButton(accent: PaperTheme.cream.redInk) {}
            AIButton(accent: PaperTheme.cream.greenInk) {}
        }
        .padding(40)
    }
    .paperTheme(.cream)
}
