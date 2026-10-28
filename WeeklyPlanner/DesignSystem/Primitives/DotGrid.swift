import SwiftUI

/// Dot-grid paper (Phase 44). Same 28pt rhythm as `RuledLines` so page
/// content lines up regardless of template.
struct DotGrid: View {
    @Environment(\.paperTheme) private var theme

    private static let spacing: CGFloat = 28
    private static let dotRadius: CGFloat = 1.1

    var body: some View {
        Canvas { context, size in
            let shading = GraphicsContext.Shading.color(theme.rule)
            var y = Self.spacing
            while y < size.height {
                var x = Self.spacing
                while x < size.width {
                    let rect = CGRect(x: x - Self.dotRadius,
                                      y: y - Self.dotRadius,
                                      width: Self.dotRadius * 2,
                                      height: Self.dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: shading)
                    x += Self.spacing
                }
                y += Self.spacing
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
