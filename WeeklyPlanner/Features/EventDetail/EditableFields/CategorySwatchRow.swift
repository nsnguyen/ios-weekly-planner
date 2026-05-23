import SwiftUI

/// Editable category picker: four ink dots with the selected swatch
/// drawing a 1.5pt ink ring around it. The four dots correspond to the
/// `Category` cases that appear in the mocks; we expose all six on the
/// underlying enum but only display the four "primary" categories here.
///
/// Tapping a dot calls the binding setter. No mid-state — selection
/// commits immediately.
struct CategorySwatchRow: View {
    @Binding var selection: Category

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    private static let displayed: [Category] = [.personal, .work, .health, .family]

    var body: some View {
        HStack(spacing: 14) {
            Text("Category")
                .font(font.font(at: 15 * size.scale, weight: .regular))
                .foregroundStyle(theme.ink2)
                .frame(width: 72, alignment: .leading)

            HStack(spacing: 14) {
                ForEach(Self.displayed, id: \.self) { category in
                    swatch(for: category)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.ink3)
                .frame(height: 0.5)
        }
    }

    private func swatch(for category: Category) -> some View {
        let isSelected = selection == category
        return Button {
            selection = category
        } label: {
            ZStack {
                Circle()
                    .fill(CategoryPalette.dot(category))
                    .frame(width: 22, height: 22)

                if isSelected {
                    Circle()
                        .stroke(theme.ink, lineWidth: 1.5)
                        .frame(width: 30, height: 30)
                }
            }
            .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CategoryPalette.displayName(category))
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
