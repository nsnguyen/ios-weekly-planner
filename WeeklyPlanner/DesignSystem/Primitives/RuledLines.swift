import SwiftUI

/// Faint horizontal rules running the full width of the page, repeating
/// every `lineSpacing` (28pt) from the top edge down. Color is `theme.rule`,
/// which is already a translucent brown / dark navy depending on the theme.
///
/// Drawn in a `Canvas` so the page paints all rules in a single pass instead
/// of stacking ~25 `Rectangle()` views — important on tall screens where the
/// view-tree cost compounds.
///
/// Layering role: drawn INSIDE a `PaperSurface`, above `PaperGrain` but below
/// the red margin line, hole punches, and any text content. The caller is
/// responsible for ensuring text sits visually on top of the rules.
struct RuledLines: View {
    @Environment(\.paperTheme) private var theme

    /// Vertical distance between rules. Matches the mock's 28pt grid.
    private static let lineSpacing: CGFloat = 28

    /// Thickness of each rule.
    private static let lineThickness: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let shading = GraphicsContext.Shading.color(theme.rule)
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0,
                                  y: y,
                                  width: size.width,
                                  height: Self.lineThickness)
                context.fill(Path(rect), with: shading)
                y += Self.lineSpacing
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview("RuledLines · Cream") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                RuledLines()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}

#Preview("RuledLines · Kraft") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                RuledLines()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.kraft)
}

#Preview("RuledLines · Midnight") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                RuledLines()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.midnight)
}
