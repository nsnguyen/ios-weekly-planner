import SwiftUI

/// Yellow "SUGGESTED" sticky tucked at the bottom of the Paper Event
/// Detail sheet. Renders only when `suggestion` is non-empty so callers
/// can always instantiate it without a guard — the view collapses to
/// `EmptyView` when there's nothing to show.
///
/// Colors are deliberately theme-independent (yellow paper + warm-brown
/// ink) because a sticky should read identically across Cream / Kraft /
/// Midnight — the spec calls these out as the only hex literals that
/// belong inline in this file.
struct EventAISticky: View {
    /// The suggestion copy. Comes from `EventDetailViewModel.aiSuggestion`,
    /// which routes through `EventAISuggestion.text(for:)`.
    let suggestion: String

    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        if suggestion.isEmpty {
            EmptyView()
        } else {
            stickyBody
        }
    }

    // MARK: - Subviews

    /// The actual sticky card. Split out so the top-level `body` can stay
    /// a single `if` expression.
    private var stickyBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow
                .padding(.bottom, 3)

            Text(suggestion)
                .font(font.font(at: 16 * size.scale, weight: .semibold))
                .lineSpacing(1.2)
                .foregroundStyle(Color(hex: "#3A2A1A"))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        .background(Color(hex: "#FFE680"))
        .cornerRadius(1)
        .rotationEffect(.degrees(-0.6))
        .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 3)
    }

    /// Eyebrow row: sparkles glyph + tracked "SUGGESTED" label. Tints are
    /// pulled directly from the spec — translucent black so they read on
    /// any sticky color.
    private var eyebrow: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 9))
                .foregroundStyle(Color.black.opacity(0.45))

            Text("SUGGESTED")
                .font(.system(size: 8, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.black.opacity(0.45))
        }
    }
}

// MARK: - Previews

#Preview("EventAISticky · Cream") {
    ZStack {
        BookCover()
        EventAISticky(suggestion: "Order an Uber at 7:35 PM. Trick Dog is a 22-min drive Saturday night.")
            .padding(.horizontal, 18)
            .background(PaperTheme.cream.cream)
            .padding(40)
    }
    .paperTheme(.cream)
}
