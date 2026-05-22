import SwiftUI

/// Editable location row: leading `mappin.circle` glyph + handwriting
/// label, trailing `InkTextField` bound to the composer's location
/// string. Optional — empty location is valid.
struct LocationField: View {
    @Binding var text: String

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.ink3)
                Text("Location")
                    .font(font.font(at: 15 * size.scale, weight: .regular))
                    .foregroundStyle(theme.ink2)
            }
            .frame(width: 110, alignment: .leading)

            InkTextField("Add a place…", text: $text, variant: .body)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.ink3)
                .frame(height: 0.5)
        }
    }
}
