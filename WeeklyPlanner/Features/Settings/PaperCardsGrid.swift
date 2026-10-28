import SwiftUI

/// 2-column grid of paper-template cards (Phase 44). Four templates fill
/// two rows.
struct PaperCardsGrid: View {
    let selection: PaperTemplate
    let onPick: (PaperTemplate) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(PaperTemplate.allCases, id: \.self) { template in
                PaperCard(template: template, isActive: template == selection) {
                    onPick(template)
                }
            }
        }
        .padding(.bottom, 14)
    }
}

private struct PaperCard: View {
    let template: PaperTemplate
    let isActive: Bool
    let onPick: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        Button(action: onPick) {
            VStack(alignment: .leading, spacing: 8) {
                preview
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.rule, lineWidth: 0.5))

                Text(template.displayName)
                    .font(font.font(at: 15, weight: .regular))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(theme.creamHi))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isActive ? theme.blueInk : theme.rule,
                              lineWidth: isActive ? 1.5 : 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.displayName)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(AccessibilityIDs.settingsPaperCard(template.rawValue))
    }

    private var preview: some View {
        ZStack {
            theme.cream
            switch template {
            case .ruled:
                RuledLines()
                RedMarginLine()
            case .blank:
                EmptyView()
            case .dotGrid:
                DotGrid()
            case .grid:
                GridLines()
            }
        }
        .environment(\.paperTemplate, template)
    }
}
