import SwiftUI

/// "Streaks" section: wavy-underlined header + a row per `Streak`. Each
/// row shows the emoji, "Name · N weeks", a 7-cell pill row (filled
/// green for completed days, neutral otherwise), and a trailing 🔥.
struct StreaksBlock: View {
    let streaks: [Streak]

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Streaks")
                .font(font.font(at: 20, weight: .bold))
                .foregroundStyle(theme.ink)
                .modifier(WavyUnderline(color: theme.ink.opacity(0.25),
                                         amplitude: 1,
                                         wavelength: 6))
                .padding(.bottom, 8)

            ForEach(streaks, id: \.id) { streak in
                HStack(alignment: .center, spacing: 10) {
                    Text(streak.emoji)
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(streak.name) · \(streak.consecutiveWeeks) weeks")
                            .font(font.font(at: 17, weight: .regular))
                            .foregroundStyle(theme.ink)
                        HStack(spacing: 3) {
                            ForEach(0 ..< 7, id: \.self) { idx in
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(streak.last7Days.indices.contains(idx) && streak.last7Days[idx]
                                          ? theme.greenInk
                                          : Color.black.opacity(0.08))
                                    .frame(height: 5)
                            }
                        }
                        .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("🔥")
                        .font(.system(size: 18))
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(streak.name): \(streak.consecutiveWeeks)-week streak")
            }
        }
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
}
