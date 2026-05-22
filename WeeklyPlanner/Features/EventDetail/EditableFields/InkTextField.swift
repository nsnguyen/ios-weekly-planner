import SwiftUI

/// Handwriting-styled `TextField` atom used by every editable field in
/// the event composer (Phase 22) and the task composer (Phase 23). No
/// border, ink-blue caret, italic placeholder in `theme.ink2`, blue
/// wavy underline beneath the baseline when focused.
///
/// Two preset sizes:
///   - `.title` — 22pt, used for the event title in the composer header.
///   - `.body` — 17pt, used for body fields (location, task title, …).
struct InkTextField: View {
    enum Variant { case title, body }

    @Binding var text: String
    let placeholder: String
    let variant: Variant

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    @FocusState private var focused: Bool

    init(_ placeholder: String,
         text: Binding<String>,
         variant: Variant = .body)
    {
        self.placeholder = placeholder
        self._text = text
        self.variant = variant
    }

    var body: some View {
        let basePoint: CGFloat = variant == .title ? 22 : 17
        let scaledPoint = basePoint * size.scale
        let weight: Font.Weight = variant == .title ? .bold : .regular

        return TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .font(font.font(at: scaledPoint, weight: weight))
                .foregroundStyle(theme.ink2)
        )
        .font(font.font(at: scaledPoint, weight: weight))
        .foregroundStyle(theme.ink)
        .tint(theme.blueInk)
        .textFieldStyle(.plain)
        .focused($focused)
        .overlay(alignment: .bottom) {
            if focused {
                Color.clear
                    .frame(height: 0)
                    .wavyUnderline(color: theme.blueInk.opacity(0.6),
                                   amplitude: 1,
                                   wavelength: 6)
                    .offset(y: 4)
                    .allowsHitTesting(false)
            }
        }
    }
}
