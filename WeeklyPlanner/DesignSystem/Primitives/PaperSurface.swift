import SwiftUI

/// The cream paper surface that fills a `BookPage`'s interior edge-to-edge.
///
/// Background layers, back to front:
/// 1. A flat `theme.cream` fill — guarantees the page is opaque even before
///    the radial overlay paints.
/// 2. A radial gradient overlay centered at the upper-left quadrant
///    (`UnitPoint(x: 0.18, y: 0.30)`) that fades from `theme.creamHi` →
///    `theme.cream` (at 55%) → `theme.creamLo`. This produces the soft,
///    not-quite-uniform tone of pre-printed paper.
///
/// The surface is clipped to `Spacing.bookPageCornerRadius` so when it is
/// dropped into a `BookPage` content slot it nestles inside the surrounding
/// `BookSpine` without any visible seam. Children (paper grain, ruled lines,
/// red margin, hole punches, page content) live INSIDE this clip; the surface
/// does NOT pad them — callers position children explicitly using the
/// surface's leading edge as the origin (hole punches at `leading: 8`, red
/// margin at `leading: 32`, etc.).
struct PaperSurface<Content: View>: View {
    @Environment(\.paperTheme) private var theme

    @ViewBuilder private let content: () -> Content

    /// Builds a paper surface whose child views are stacked inside the
    /// clipping shape via a `ZStack`. Pass everything that should appear on
    /// the page — paper grain overlay, ruled lines, hole punches, text, etc.
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            theme.cream

            EllipticalGradient(stops: [
                .init(color: theme.creamHi, location: 0.0),
                .init(color: theme.cream, location: 0.55),
                .init(color: theme.creamLo, location: 1.0),
            ],
            center: UnitPoint(x: 0.18, y: 0.30),
            startRadiusFraction: 0,
            endRadiusFraction: 1.0)

            content()
        }
        .clipShape(UnevenRoundedRectangle(cornerRadii: Spacing.bookPageCornerRadius,
                                          style: .continuous))
    }
}

#Preview("PaperSurface · Cream") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                Color.clear
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}

#Preview("PaperSurface · Kraft") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                Color.clear
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.kraft)
}

#Preview("PaperSurface · Midnight") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                Color.clear
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.midnight)
}
