import SwiftUI

/// A small translucent rectangle that suggests a piece of masking tape
/// holding a sticky note to the page. Used at the top of the AI day-sticky
/// (`compact`) and the week-sticky (`wide`).
///
/// The tape is a single semi-transparent fill in a warm tan
/// (`rgba(180,140,70,0.45)`) — slightly darker than cream paper, intentionally
/// flat so it reads as adhesive rather than translucent vellum. The fixed
/// alpha lets the underlying paper grain bleed through, which prevents the
/// tape from looking like a sticker decal.
///
/// `MaskingTape` only emits the rectangle at the requested size. Positioning
/// (where on the host sticky the tape sits, how far it overhangs the top
/// edge, what rotation it carries) is the caller's job. `.allowsHitTesting`
/// is disabled — tape is pure decoration, never grabs touches.
struct MaskingTape: View {
    /// Two preset widths. `compact` (32×10) is used on the standard AI
    /// sticky; `wide` (36×10) is used on the slightly larger week-sticky.
    enum Width {
        case compact
        case wide

        /// Visible width in points.
        var size: CGSize {
            switch self {
            case .compact:
                CGSize(width: 32, height: 10)
            case .wide:
                CGSize(width: 36, height: 10)
            }
        }
    }

    /// Width preset. Defaults to `.compact`.
    let width: Width

    /// Translucent tan fill — slightly darker than cream paper, deliberately
    /// non-themed so the tape reads the same on every paper theme.
    private static let tapeColor = Color.rgba(180, 140, 70, 0.45)

    init(width: Width = .compact) {
        self.width = width
    }

    var body: some View {
        Rectangle()
            .fill(Self.tapeColor)
            .frame(width: width.size.width, height: width.size.height)
            .allowsHitTesting(false)
    }
}

#Preview("MaskingTape · Cream") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                VStack(spacing: 24) {
                    MaskingTape()
                    MaskingTape(width: .wide)
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}

#Preview("MaskingTape · Kraft") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                MaskingTape(width: .wide)
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.kraft)
}

#Preview("MaskingTape · Midnight") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                MaskingTape()
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.midnight)
}
