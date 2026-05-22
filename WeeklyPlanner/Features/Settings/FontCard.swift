import SwiftUI

/// A single handwriting-font preview card. Shows a left-aligned 26pt "Aa"
/// sample, then the family display name in the same font at 15pt. Active
/// state gets a blueInk border + glow + 16pt check circle at the trailing
/// edge.
struct FontCard: View {
    let fontKey: PaperFont
    let isActive: Bool
    let onPick: () -> Void

    @Environment(\.paperTheme) private var theme

    private var sampleFont: PaperFont { fontKey }

    var body: some View {
        Button(action: onPick) {
            HStack(spacing: 10) {
                Text("Aa")
                    .font(sampleFont.font(at: 26, weight: .bold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Text(sampleFont.displayName)
                    .font(sampleFont.font(at: 15, weight: .regular))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isActive {
                    ZStack {
                        Circle().fill(theme.blueInk).frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            .background(
                RoundedRectangle(cornerRadius: 12).fill(theme.creamHi)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isActive ? theme.blueInk : theme.rule,
                                  lineWidth: isActive ? 1.5 : 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: isActive ? theme.blueInk.opacity(0.22) : .clear,
                    radius: 3, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sampleFont.displayName)
        .accessibilityHint(isActive ? "Currently selected" : "Double tap to select")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(AccessibilityIDs.settingsFontCard(fontKey.rawValue))
    }
}

#Preview("FontCard · caveat active") {
    VStack(spacing: 8) {
        FontCard(fontKey: .caveat, isActive: true) {}
        FontCard(fontKey: .architects, isActive: false) {}
    }
    .padding()
    .background(PaperTheme.cream.cream)
    .paperTheme(.cream)
}
