import SwiftUI

/// Single-row toggle cell. Lays out a label on top of an optional detail
/// (system 11pt `ink2`) on the leading side, and a `PaperToggle.regular`
/// on the trailing side. Lives inside `PreferencesGroup`'s `creamHi` card.
struct ToggleRow: View {
    let label: String
    let detail: String?
    @Binding var isOn: Bool

    @Environment(\.paperTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.ink)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.ink2)
                        .lineSpacing(1.3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            PaperToggle(isOn: $isOn, style: .regular)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
    }
}
