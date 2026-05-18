import SwiftUI

/// The "model is inferring" affordance for State B of the AI search overlay.
/// Stacks an `InkShimmerText` "thinking…" line over a quiet
/// "flipping through your pages" subhead. The shimmer's gradient sweep is
/// what carries the loading feel — the subhead is a pure label, no motion.
///
/// Padding-top 30 (per the mock) so the indicator sits visually a beat below
/// the input field, giving the user time to read it as a state change rather
/// than a layout shift.
///
/// `InkShimmerText` swaps itself into a static gradient when
/// `accessibilityReduceMotion` is `true`, so this view does not need its own
/// reduce-motion branch.
struct ThinkingIndicator: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            InkShimmerText(text: "thinking…")
                .font(font.font(at: 22, weight: .semibold))

            Text("flipping through your pages")
                .font(font.font(at: 16, weight: .regular))
                .foregroundStyle(theme.ink3)
                .padding(.top, 8)
        }
        .padding(.top, 30)
    }
}
