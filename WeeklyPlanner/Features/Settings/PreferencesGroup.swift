import SwiftUI

/// Card container for the three preference rows. Rounded-14pt rectangle
/// painted with `theme.creamHi`, 0.5pt rule border, with 0.5pt rule
/// dividers between children. Children are positioned via the trailing
/// `content` closure so the card stays agnostic of the exact rows.
struct PreferencesGroup<Content: View>: View {
    @Environment(\.paperTheme) private var theme
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 14).fill(theme.creamHi)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14).strokeBorder(theme.rule, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.bottom, 14)
    }
}

/// Convenience `View` for an inline 0.5pt rule between cells. Use after
/// every row except the last in a `PreferencesGroup`.
struct PrefRowDivider: View {
    @Environment(\.paperTheme) private var theme
    var body: some View {
        Rectangle()
            .fill(theme.rule)
            .frame(height: 0.5)
    }
}
