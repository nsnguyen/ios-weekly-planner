import SwiftUI

/// Square-grid paper (Phase 44). 28pt cells. Vertical lines use
/// `theme.ruleSoft` so text rows still dominate.
struct GridLines: View {
    @Environment(\.paperTheme) private var theme

    private static let spacing: CGFloat = 28
    private static let lineThickness: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let horizontal = GraphicsContext.Shading.color(theme.rule)
            var y = Self.spacing
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: Self.lineThickness)
                context.fill(Path(rect), with: horizontal)
                y += Self.spacing
            }

            let vertical = GraphicsContext.Shading.color(theme.ruleSoft)
            var x = Self.spacing
            while x < size.width {
                let rect = CGRect(x: x, y: 0, width: Self.lineThickness, height: size.height)
                context.fill(Path(rect), with: vertical)
                x += Self.spacing
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
