import SwiftUI

/// Floating style controls shown while an annotation is being edited:
/// five ink swatches, bold toggle, delete, done.
struct TextStyleBar: View {
    let selectedColor: InkColorToken
    let isBold: Bool
    let onColor: (InkColorToken) -> Void
    let onBoldToggle: () -> Void
    let onDelete: () -> Void
    let onDone: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            ForEach(InkColorToken.allCases, id: \.self) { token in
                Button { onColor(token) } label: {
                    Circle()
                        .fill(token.resolve(in: theme))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .strokeBorder(theme.ink, lineWidth: 2)
                                .opacity(token == selectedColor ? 1 : 0)
                                .padding(-3)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(token.rawValue) ink")
                .accessibilityAddTraits(token == selectedColor ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier(AccessibilityIDs.annotationStyleColor(token.rawValue))
            }

            Rectangle().fill(theme.rule).frame(width: 0.5, height: 16)

            Button(action: onBoldToggle) {
                Text(verbatim: "B")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(isBold ? theme.ink : theme.ink3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Bold")
            .accessibilityAddTraits(isBold ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier(AccessibilityIDs.annotationStyleBold)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.redInk)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete annotation")
            .accessibilityIdentifier(AccessibilityIDs.annotationStyleDelete)

            Button(action: onDone) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.blueInk)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done editing")
            .accessibilityIdentifier(AccessibilityIDs.annotationStyleDone)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.creamHi)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        )
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.rule, lineWidth: 0.5))
    }
}

#Preview("TextStyleBar · cream") {
    TextStyleBar(selectedColor: .red, isBold: true,
                 onColor: { _ in }, onBoldToggle: {}, onDelete: {}, onDone: {})
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
