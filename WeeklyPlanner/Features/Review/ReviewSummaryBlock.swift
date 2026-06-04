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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI summary: \(summaryBody)")
    }
}

/// Honest AI-off state for the Review page (Phase 32 #38): one quiet line
/// inviting the user to enable Ask the planner — in place of the old canned
/// summary, which read as fake and couldn't be dismissed.
struct ReviewAIOffPrompt: View {
    /// Exposed for tests; also the VoiceOver label.
    static let promptText = String(localized: "Turn on Ask the planner for a weekly summary")

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 10))
                .foregroundStyle(theme.ink3)
            Text(Self.promptText)
                .font(font.font(at: 15, weight: .regular).italic())
                .foregroundStyle(theme.ink3)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.promptText)
    }
}
