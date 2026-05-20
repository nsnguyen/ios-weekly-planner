import SwiftUI

/// Top-of-page banner shown inside the `BookPage`. Two lines of text plus
/// a 2pt gradient rule that fades to transparent at 100% — matches the
/// header used by the Calendar page header but with a settings-specific
/// title + subtitle.
struct SettingsHeader: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Make it yours")
                .font(font.font(at: 30 * size.scale, weight: .bold))
                .foregroundStyle(theme.ink)
                .padding(EdgeInsets(top: 14, leading: 18, bottom: 4, trailing: 18))

            Text("Theme, handwriting, connections.")
                .font(.custom("Cochin-Italic", size: 12))
                .foregroundStyle(theme.ink2)
                .italic()
                .padding(EdgeInsets(top: 0, leading: 18, bottom: 6, trailing: 18))

            LinearGradient(stops: [
                .init(color: theme.ink, location: 0.0),
                .init(color: theme.ink, location: 0.6),
                .init(color: .clear, location: 1.0),
            ], startPoint: .leading, endPoint: .trailing)
                .opacity(0.4)
                .frame(height: 2)
                .padding(EdgeInsets(top: 6, leading: 18, bottom: 8, trailing: 18))
        }
    }
}

#Preview("SettingsHeader · cream") {
    SettingsHeader()
        .padding(.leading, 32)
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
