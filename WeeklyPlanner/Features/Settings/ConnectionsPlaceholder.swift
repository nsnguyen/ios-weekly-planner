import SwiftUI

/// Phase 16 placeholder for the Connections section. Phase 17 replaces the
/// body of this file with real Gmail / Apple Mail / Google Calendar rows.
/// Keeping a dedicated file (instead of inlining) means Phase 17's diff is
/// a single-file replacement with no churn on `PaperSettingsView`.
struct ConnectionsPlaceholder: View {
    @Environment(\.paperTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Connections")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.ink)
            Text("Coming up next…")
                .font(.system(size: 11))
                .foregroundStyle(theme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .background(
            RoundedRectangle(cornerRadius: 14).fill(theme.creamHi)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14).strokeBorder(theme.rule, lineWidth: 0.5)
        )
        .padding(.bottom, 14)
    }
}

#Preview("ConnectionsPlaceholder") {
    ConnectionsPlaceholder()
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
