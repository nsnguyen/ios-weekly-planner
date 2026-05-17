import SwiftUI

/// Three soft radial gradient blobs giving the paper page a not-completely-flat
/// tone. Each blob is a brown radial fall-off positioned at a different region
/// of the page; together they suggest very faint ink/oil flecks in the pulp.
///
/// Rendered via a single `Canvas` pass (one shading per blob) instead of a
/// stack of three `RadialGradient` views — keeps the view tree flat and the
/// blend cheap.
///
/// The whole view is composited at `opacity: 0.35` with `.blendMode(.multiply)`
/// so the blobs darken the underlying paper without painting brown on top of
/// it. `.allowsHitTesting(false)` because this is pure decoration.
///
/// Layering role: drawn INSIDE a `PaperSurface`, immediately above the cream
/// background but below ruled lines, red margin, hole punches, and content.
struct PaperGrain: View {
    @Environment(\.paperTheme) private var theme

    /// One grain blob: a position in unit-space (0...1) over the view, the
    /// radius in points, and the alpha of the brown at the blob's center.
    private struct Blob {
        let unitX: CGFloat
        let unitY: CGFloat
        let radius: CGFloat
        let centerAlpha: Double
    }

    /// Brown pigment used by every blob. Alpha is stored on the gradient
    /// stops (so blobs of different opacity share one color).
    private static let pigment = Color.rgba(139, 121, 80, 1.0)

    private static let blobs: [Blob] = [
        Blob(unitX: 0.12, unitY: 0.84, radius: 60, centerAlpha: 0.07),
        Blob(unitX: 0.88, unitY: 0.22, radius: 80, centerAlpha: 0.05),
        Blob(unitX: 0.60, unitY: 0.70, radius: 100, centerAlpha: 0.04),
    ]

    var body: some View {
        Canvas { context, size in
            for blob in Self.blobs {
                let center = CGPoint(x: blob.unitX * size.width,
                                     y: blob.unitY * size.height)
                let shading = GraphicsContext.Shading.radialGradient(Gradient(stops: [
                    .init(color: Self.pigment.opacity(blob.centerAlpha), location: 0.0),
                    .init(color: Self.pigment.opacity(0.0), location: 1.0),
                ]),
                center: center,
                startRadius: 0,
                endRadius: blob.radius)
                let rect = CGRect(x: center.x - blob.radius,
                                  y: center.y - blob.radius,
                                  width: blob.radius * 2,
                                  height: blob.radius * 2)
                context.fill(Path(rect), with: shading)
            }
        }
        .opacity(0.35)
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }
}

#Preview("PaperGrain · Cream") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                PaperGrain()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}

#Preview("PaperGrain · Kraft") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                PaperGrain()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.kraft)
}

#Preview("PaperGrain · Midnight") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                PaperGrain()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.midnight)
}
