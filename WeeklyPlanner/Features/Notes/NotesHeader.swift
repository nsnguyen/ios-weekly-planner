import SwiftUI

/// Top-of-page banner for the Notes tab. Mirrors `SettingsHeader`.
struct NotesHeader: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notes")
                .font(font.font(at: 30 * size.scale, weight: .bold))
                .foregroundStyle(theme.ink)
                .padding(EdgeInsets(top: 14, leading: 18, bottom: 4, trailing: 18))

            Text("Goals, scraps, anything.")
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

#Preview("NotesHeader · cream") {
    NotesHeader()
        .padding(.leading, 32)
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
