import SwiftUI

/// Expandable preference row. Tap the value chevron → expands to a wrap-row
/// of option pills, one of which is highlighted with the blueInk border +
/// 10% fill. Selecting a pill calls `onSelect` and collapses the row.
///
/// Uses 0.22s ease for the chevron rotation + reveal (per Phase 16 spec).
struct PrefRow<Option: Hashable & CustomStringConvertible>: View {
    let label: String
    let value: Option
    let options: [Option]
    let onSelect: (Option) -> Void

    @Environment(\.paperTheme) private var theme
    @State private var isOpen: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(describing: value))
                        .font(.system(size: 14))
                        .foregroundStyle(theme.ink2)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.ink3)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            }
            .buttonStyle(.plain)

            if isOpen {
                optionsRow
                    .padding(EdgeInsets(top: 0, leading: 14, bottom: 10, trailing: 14))
                    .transition(.opacity)
            }
        }
    }

    private var optionsRow: some View {
        HStack(alignment: .center, spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                    withAnimation(.easeInOut(duration: 0.22)) { isOpen = false }
                } label: {
                    Text(String(describing: option))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .padding(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
                        .background(
                            Capsule().fill(option == value
                                ? theme.blueInk.opacity(0.10)
                                : Color.clear)
                        )
                        .overlay(
                            Capsule().strokeBorder(option == value
                                ? theme.blueInk
                                : theme.rule,
                                lineWidth: option == value ? 1.0 : 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
