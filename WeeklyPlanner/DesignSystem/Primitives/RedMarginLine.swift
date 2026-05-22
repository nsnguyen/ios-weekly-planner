import SwiftUI

/// The thin red vertical rule that runs full-height down the page at
/// `leading: Spacing.redMarginLeading` (32pt) from the surface's leading edge.
/// Color is `theme.redLine` — translucent red on cream/kraft, translucent
/// salmon on midnight.
///
/// Implementation uses a frame-stack rather than `GeometryReader`: a
/// `Rectangle` is sized 1pt wide, expanded vertically with
/// `frame(maxHeight: .infinity)`, then padded from the leading edge by the
/// margin constant. The outer `frame(maxWidth: .infinity, alignment: .leading)`
/// makes sure the line stays pinned to the left after the padding is applied.
///
/// Layering role: drawn INSIDE a `PaperSurface`, above ruled lines but below
/// the hole punches and any content text. `.allowsHitTesting(false)` so taps
/// pass through to anything underneath.
struct RedMarginLine: View {
    @Environment(\.paperTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.redLine)
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, Spacing.redMarginLeading)
            .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("RedMarginLine · Cream") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                RedMarginLine()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}

#Preview("RedMarginLine · Kraft") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                RedMarginLine()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.kraft)
}

#Preview("RedMarginLine · Midnight") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                RedMarginLine()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.midnight)
}
