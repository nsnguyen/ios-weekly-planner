import SwiftUI

/// Top of the Review page: handwritten title + Cochin date range on the
/// left, rotated 48pt completion-percent on the right, divided by a
/// linear-gradient hairline. Pure view — all data flows in via init.
struct ReviewHeader: View {
    /// Week relative to today's week. Used for the "Week {N}" label.
    let weekOffset: Int
    /// Date range string, e.g. "11 – 17 May 2026". Pre-formatted by the
    /// caller so the view stays formatter-free.
    let dateRange: String
    /// 0.0–1.0 task completion share.
    let completionPercent: Double

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Week \(weekOffset == 0 ? "this" : "\(weekOffset)") · In review")
                    .font(font.font(at: 28, weight: .bold))
                    .lineSpacing(0)
                    .tracking(-0.5)
                    .foregroundStyle(theme.ink)
                Text(dateRange)
                    .font(.custom("Cochin-Italic", size: 12))
                    .foregroundStyle(theme.ink2)
            }
            Spacer(minLength: 0)
            Text("\(Int((completionPercent * 100).rounded()))%")
                .font(font.font(at: 48, weight: .bold))
                .lineSpacing(0)
                .foregroundStyle(theme.ink.opacity(0.85))
                .rotationEffect(.degrees(-3))
                .multilineTextAlignment(.trailing)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [theme.ink.opacity(0.45),
                                     theme.ink.opacity(0.45),
                                     .clear],
                           startPoint: .leading,
                           endPoint: .trailing)
                .frame(height: 2)
                .offset(y: 8)
        }
        .padding(.bottom, 10)
    }
}
