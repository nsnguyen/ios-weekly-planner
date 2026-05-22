import SwiftUI

/// "Notes from AI" section: wavy-underlined header + a list of
/// `WeekSummary.Bullet` rows, each leading with a ★ in its ink color.
struct AINotesList: View {
    let bullets: [WeekSummary.Bullet]

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notes from AI")
                .font(font.font(at: 20, weight: .bold))
                .foregroundStyle(theme.ink)
                .modifier(WavyUnderline(color: theme.ink.opacity(0.25),
                                         amplitude: 1,
                                         wavelength: 6))
                .padding(.bottom, 8)

            ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("★")
                        .font(font.font(at: 18, weight: .regular))
                        .foregroundStyle(color(for: bullet.ink))
                    Text(bullet.text)
                        .font(font.font(at: 16, weight: .regular))
                        .lineSpacing(1.25)
                        .foregroundStyle(color(for: bullet.ink))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 3)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("AI note: \(bullet.text)")
            }
        }
        .padding(.top, 18)
    }

    private func color(for ink: WeekSummary.Ink) -> Color {
        switch ink {
        case .dark: return theme.ink
        case .green: return theme.greenInk
        case .red: return theme.redInk
        case .blue: return theme.blueInk
        }
    }

    /// Test hook — string-keyed mapping that tests can assert without
    /// reaching into SwiftUI's environment.
    static func inkKey(_ ink: WeekSummary.Ink) -> String {
        switch ink {
        case .dark: return "ink"
        case .green: return "greenInk"
        case .red: return "redInk"
        case .blue: return "blueInk"
        }
    }
}
