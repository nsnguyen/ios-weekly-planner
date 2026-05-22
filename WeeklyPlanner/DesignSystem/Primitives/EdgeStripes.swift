import SwiftUI

/// The repeating stacked-paper stripe pattern on the trailing edge of a
/// `BookPage`. Six points wide; alternates 2pt of `theme.edgeStripeLight`
/// with 2pt of `theme.edgeStripeDark` along the vertical axis, suggesting
/// the visible side of many bound pages stacked together.
///
/// Drawn in a `Canvas` so the alternating bands are rendered as ~150 small
/// rectangles per pass rather than ~150 stacked `Rectangle` views — keeps
/// the view tree small even on tall screens.
///
/// Layering role: positioned by `BookPage` against the trailing edge of the
/// spine, inset 6pt from the top and bottom. Sits below page content but
/// above the dark spine fill (z-index 1 in the mock).
struct EdgeStripes: View {
    @Environment(\.paperTheme) private var theme

    /// Height of one stripe band (light or dark).
    private static let bandHeight: CGFloat = 2

    /// Width of the inner shadow strip along the trailing edge.
    private static let shadowWidth: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            let bandHeight = Self.bandHeight
            let lightColor = GraphicsContext.Shading.color(theme.edgeStripeLight)
            let darkColor = GraphicsContext.Shading.color(theme.edgeStripeDark)

            var y: CGFloat = 0
            var useLight = true
            while y < size.height {
                let rect = CGRect(x: 0,
                                  y: y,
                                  width: size.width,
                                  height: min(bandHeight, size.height - y))
                context.fill(Path(rect), with: useLight ? lightColor : darkColor)
                y += bandHeight
                useLight.toggle()
            }
        }
        .overlay(alignment: .trailing) {
            // Inner shadow on the right edge (CSS: inset -1pt 0 2pt rgba(0,0,0,0.25)).
            LinearGradient(colors: [.clear, Color.black.opacity(0.25)],
                           startPoint: .leading,
                           endPoint: .trailing)
                .frame(width: Self.shadowWidth)
                .allowsHitTesting(false)
        }
        .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0,
                                                             bottomLeading: 0,
                                                             bottomTrailing: 6,
                                                             topTrailing: 6)))
        .accessibilityHidden(true)
    }
}

#Preview("EdgeStripes · Cream") {
    ZStack(alignment: .trailing) {
        BookCover()
        EdgeStripes()
            .frame(width: Spacing.pageEdgeStripeWidth, height: 400)
            .padding(.trailing, 40)
    }
    .paperTheme(.cream)
}

#Preview("EdgeStripes · Kraft") {
    ZStack(alignment: .trailing) {
        BookCover()
        EdgeStripes()
            .frame(width: Spacing.pageEdgeStripeWidth, height: 400)
            .padding(.trailing, 40)
    }
    .paperTheme(.kraft)
}

#Preview("EdgeStripes · Midnight") {
    ZStack(alignment: .trailing) {
        BookCover()
        EdgeStripes()
            .frame(width: Spacing.pageEdgeStripeWidth, height: 400)
            .padding(.trailing, 40)
    }
    .paperTheme(.midnight)
}
