import SwiftUI

/// A single theme preview card. Paints the candidate theme's own `cream`
/// background so the user sees the color immediately. Active state adds a
/// blueInk border, outer 3pt blueInk@22% glow, and a check circle at top-left.
struct ThemeCard: View {
    let themeKey: PaperThemeKey
    let isActive: Bool
    let onPick: () -> Void

    /// The active theme — used only for the `blueInk` accent. The card's
    /// own visual surface uses `cardTheme` (the candidate it represents).
    @Environment(\.paperTheme) private var activeTheme
    @Environment(\.paperFont) private var font

    private var cardTheme: PaperTheme { themeKey.theme }

    var body: some View {
        Button(action: onPick) {
            ZStack(alignment: .topLeading) {
                cardTheme.cream

                cardTheme.bookCover
                    .frame(width: 30, height: 30)
                    .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0,
                                                                          bottomLeading: 12,
                                                                          bottomTrailing: 0,
                                                                          topTrailing: 12)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Aa")
                        .font(font.font(at: 26, weight: .bold))
                        .foregroundStyle(cardTheme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(cardTheme.displayName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(cardTheme.ink)
                    Text(cardTheme.tag)
                        .font(.system(size: 10))
                        .foregroundStyle(cardTheme.ink2)
                }
                .padding(EdgeInsets(top: 10, leading: 8, bottom: 8, trailing: 8))

                if isActive {
                    activeIndicator
                        .padding(EdgeInsets(top: 6, leading: 6, bottom: 0, trailing: 0))
                }
            }
            .frame(minHeight: 84)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(cardTheme.cream)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isActive ? activeTheme.blueInk : cardTheme.rule,
                                  lineWidth: isActive ? 1.5 : 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: isActive ? activeTheme.blueInk.opacity(0.22) : .clear,
                    radius: 3, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cardTheme.displayName)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private var activeIndicator: some View {
        ZStack {
            Circle().fill(activeTheme.blueInk).frame(width: 16, height: 16)
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview("ThemeCard · all three") {
    HStack(spacing: 8) {
        ThemeCard(themeKey: .cream, isActive: true) {}
        ThemeCard(themeKey: .kraft, isActive: false) {}
        ThemeCard(themeKey: .midnight, isActive: false) {}
    }
    .padding()
    .background(PaperTheme.cream.cream)
    .paperTheme(.cream)
}
