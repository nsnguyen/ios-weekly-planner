import SwiftUI

/// The three 12×12pt circular hole-punches running down the leading edge of
/// the page at `leading: Spacing.holePunchLeading` (8pt). Vertical layout:
/// the top dot sits 60pt from the top, the third dot 60pt from the bottom,
/// and the middle dot is exactly vertically centered between them.
///
/// Each dot is `theme.holePunch` and carries a faint inner shadow
/// (`inset 0 1 2 rgba(0,0,0,0.2)`) approximated by stacking a slightly smaller
/// darker `Circle` BENEATH it: SwiftUI lacks a first-class inset-shadow, but
/// laying a blurred translucent black disk under a slightly inset cream disk
/// yields the same ring of darkness around the inside rim. The effect is
/// subtle on purpose — easy to overdo.
///
/// Layering role: drawn INSIDE a `PaperSurface`, above the red margin line,
/// below page content. `.allowsHitTesting(false)`.
struct HolePunches: View {
    @Environment(\.paperTheme) private var theme

    /// Distance from the top/bottom edges to the top/bottom dot.
    private static let endInset: CGFloat = 60

    var body: some View {
        VStack(spacing: 0) {
            punch
                .padding(.top, Self.endInset)
            Spacer(minLength: 0)
            punch
            Spacer(minLength: 0)
            punch
                .padding(.bottom, Self.endInset)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Spacing.holePunchLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A single hole-punch dot with an inner-shadow approximation.
    /// The blurred disk is drawn first, then a slightly inset cream disk
    /// on top so only a ring of darkness peeks out around the rim.
    private var punch: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.20))
                .frame(width: Spacing.holePunchSize, height: Spacing.holePunchSize)
                .blur(radius: 1)

            Circle()
                .fill(theme.holePunch)
                .frame(width: Spacing.holePunchSize - 1.5,
                       height: Spacing.holePunchSize - 1.5)
                .offset(y: -0.5)
        }
        .frame(width: Spacing.holePunchSize, height: Spacing.holePunchSize)
    }
}

#Preview("HolePunches · Cream") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                HolePunches()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}

#Preview("HolePunches · Kraft") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                HolePunches()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.kraft)
}

#Preview("HolePunches · Midnight") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                HolePunches()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.midnight)
}
