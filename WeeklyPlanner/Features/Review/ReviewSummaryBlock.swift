import SwiftUI

/// The "AI SUMMARY" block: small sparkle eyebrow over a handwritten
/// blue-ink paragraph. Pure view; the parent passes in the resolved body.
struct ReviewSummaryBlock: View {
    let summaryBody: String

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.ink3)
                Text("AI SUMMARY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(theme.ink3)
            }
            Text(summaryBody)
                .font(font.font(at: 18, weight: .regular))
                .lineSpacing(1.25)
                .tracking(0.1)
                .foregroundStyle(theme.blueInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }
}
