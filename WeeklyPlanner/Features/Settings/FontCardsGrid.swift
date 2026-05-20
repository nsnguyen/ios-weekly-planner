import SwiftUI

/// 2-column grid of `FontCard`s. Iterates `PaperFont.allCases` in
/// declaration order: caveat → architects → kalam → indie. 8pt gap,
/// 14pt bottom margin to space the next section.
struct FontCardsGrid: View {
    let selection: PaperFont
    let onPick: (PaperFont) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(PaperFont.allCases, id: \.self) { font in
                FontCard(fontKey: font, isActive: font == selection) { onPick(font) }
            }
        }
        .padding(.bottom, 14)
    }
}

#Preview("FontCardsGrid · architects active") {
    FontCardsGrid(selection: .architects) { _ in }
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
