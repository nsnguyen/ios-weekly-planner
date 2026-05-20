import SwiftUI

/// Centered italic trailer at the bottom of `PaperSettingsView`'s scroll
/// content. Handwriting 16pt at `ink3`. 10pt vertical padding so the row
/// sits comfortably above the scroll bottom.
struct AboutFooter: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        Text("The Planner · v1.0 · made with care")
            .font(font.font(at: 16 * size.scale, weight: .regular))
            .italic()
            .foregroundStyle(theme.ink3)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
    }
}

#Preview("AboutFooter · cream") {
    AboutFooter()
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
