import SwiftUI

/// Small 34×34 capsule button that opens the Apple Intelligence overlay from
/// the trailing edge of the planner's top bar. Renders a single SF Symbol
/// `sparkles` glyph tinted in a fixed light-blue accent over a faint
/// translucent chrome background, so the button reads as "live AI" against
/// the dark leather cover behind it.
///
/// The accent is theme-independent (hard-coded `#7DB0F2` light blue) for the
/// same reason the date-range pill's title is hard-coded `#FAF6E9`: this
/// button always sits on dark leather, so a single high-contrast value reads
/// correctly across every paper theme (Cream, Kraft, Midnight). Background
/// and border tints stay fixed white-on-leather values
/// (`Color.white.opacity(0.12)` border, `0.06` fill).
struct AIButton: View {
    /// Color of the sparkles glyph. Defaults to a fixed light blue
    /// (`#7DB0F2`) chosen to read clearly against the dark leather cover the
    /// button always sits on. Callers normally leave this at the default.
    var accent: Color = .init(hex: "#7DB0F2")

    /// Invoked when the user taps the button. The parent shows the AI overlay
    /// (Phase 12); this primitive only emits the tap.
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                Capsule()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundStyle(accent)
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibleAIButton()
        .accessibilityIdentifier(AccessibilityIDs.daypageAIButton)
    }
}

// MARK: - Previews

#Preview("AIButton · default over leather") {
    ZStack {
        BookCover()
        HStack(spacing: 16) {
            AIButton {}
            AIButton(accent: PaperTheme.cream.redInk) {}
            AIButton(accent: PaperTheme.cream.greenInk) {}
        }
        .padding(40)
    }
    .paperTheme(.cream)
}
