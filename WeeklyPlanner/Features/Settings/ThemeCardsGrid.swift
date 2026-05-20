import SwiftUI

/// 3-column grid of `ThemeCard`s. Iterates `PaperThemeKey.allCases` in
/// declaration order: cream → kraft → midnight. 8pt column gap, 14pt
/// bottom margin so the next section breathes.
struct ThemeCardsGrid: View {
    let selection: PaperThemeKey
    let onPick: (PaperThemeKey) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(PaperThemeKey.allCases, id: \.self) { key in
                ThemeCard(themeKey: key, isActive: key == selection) { onPick(key) }
            }
        }
        .padding(.bottom, 14)
    }
}

#Preview("ThemeCardsGrid · cream active") {
    StatefulPreviewWrapper(PaperThemeKey.cream) { binding in
        ThemeCardsGrid(selection: binding.wrappedValue) { binding.wrappedValue = $0 }
            .padding()
            .background(PaperTheme.cream.cream)
    }
    .paperTheme(.cream)
}

private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}
