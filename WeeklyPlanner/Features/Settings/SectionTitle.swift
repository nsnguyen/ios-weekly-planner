import SwiftUI

/// Section heading used 5× on `PaperSettingsView`: an optional uppercase
/// eyebrow ("LOOK & FEEL", "SOURCES") on top of a 22pt handwriting title.
/// Sits flush-left under the gradient rule, padded `(0, 2, 8, 0)` so the
/// title baseline lines up with the section's content.
struct SectionTitle: View {
    let title: String
    let eyebrow: String?

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    init(_ title: String, eyebrow: String? = nil) {
        self.title = title
        self.eyebrow = eyebrow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(theme.ink3)
            }
            Text(title)
                .font(font.font(at: 22 * size.scale, weight: .bold))
                .foregroundStyle(theme.ink)
        }
        .padding(EdgeInsets(top: 0, leading: 2, bottom: 8, trailing: 0))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("SectionTitle · cream") {
    VStack(alignment: .leading, spacing: 12) {
        SectionTitle("Theme", eyebrow: "Look & feel")
        SectionTitle("Handwriting")
    }
    .padding()
    .background(PaperTheme.cream.cream)
    .paperTheme(.cream)
}
