import SwiftUI

/// A `Shape` whose top edge is a zigzag — the visual signature of the
/// `PaperEventSheet` introduced in Phase 11. The bottom three sides remain
/// rectangular so the shape can be used interchangeably as `.clipShape(...)`
/// for a sheet's bounds or as a fillable `Shape` for an accent stroke.
///
/// Geometry: the top edge is a sequence of 40pt-wide × 10pt-tall tiles laid
/// end-to-end across `rect.width`. Each tile traces the points
/// `M0 10 L5 4 L10 8 L15 2 L20 7 L25 3 L30 9 L35 4 L40 10` in tile-local
/// coordinates — eight irregular peaks that read as "torn" rather than "saw
/// blade." After the last tile, the path runs down the trailing edge to
/// `rect.maxY`, across the bottom to `(rect.minX, rect.maxY)`, and back up
/// to `(rect.minX, tileHeight)` where it began, closing into a full shape.
///
/// The 30%-overlap softening called out in `phase-05-paper-primitives.md` is
/// the caller's responsibility — `TornEdgeShape` emits the raw geometry and
/// callers compose a softer look on top via masks, blurs, or stacked fills.
///
/// `tileWidth` / `tileHeight` are exposed as static constants so tests and
/// callers can reference them without duplicating literals.
struct TornEdgeShape: Shape {
    /// Width of one zigzag tile.
    static let tileWidth: CGFloat = 40

    /// Height (depth) of the zigzag region above the rectangular body.
    static let tileHeight: CGFloat = 10

    /// Local (x, y) coordinates of the zigzag spine within a single tile.
    /// Values are read from `phase-05-paper-primitives.md`.
    private static let tilePoints: [CGPoint] = [
        CGPoint(x: 0, y: 10),
        CGPoint(x: 5, y: 4),
        CGPoint(x: 10, y: 8),
        CGPoint(x: 15, y: 2),
        CGPoint(x: 20, y: 7),
        CGPoint(x: 25, y: 3),
        CGPoint(x: 30, y: 9),
        CGPoint(x: 35, y: 4),
        CGPoint(x: 40, y: 10),
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0, rect.height > 0 else { return path }

        let tileCount = max(1, Int(ceil(rect.width / Self.tileWidth)))

        // Walk every tile along the top edge, in screen coordinates. The
        // first tile's first point seeds the path's `move(to:)`; every
        // subsequent point is `addLine(to:)`.
        for tileIndex in 0 ..< tileCount {
            let tileOriginX = rect.minX + CGFloat(tileIndex) * Self.tileWidth
            for (pointIndex, localPoint) in Self.tilePoints.enumerated() {
                let absolute = CGPoint(x: tileOriginX + localPoint.x,
                                       y: rect.minY + localPoint.y)
                if tileIndex == 0, pointIndex == 0 {
                    path.move(to: absolute)
                } else {
                    path.addLine(to: absolute)
                }
            }
        }

        // Close down the right edge, across the bottom, and back up the
        // left edge to the starting point of the zigzag.
        let lastZigEndX = rect.minX + CGFloat(tileCount) * Self.tileWidth
        path.addLine(to: CGPoint(x: lastZigEndX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + Self.tileHeight))
        path.closeSubpath()
        return path
    }
}

#Preview("TornEdgeShape · Cream") {
    ZStack {
        BookCover()
        TornEdgeShape()
            .fill(PaperTheme.cream.cream)
            .frame(width: 320, height: 200)
            .overlay {
                TornEdgeShape()
                    .stroke(PaperTheme.cream.ink3, lineWidth: 0.5)
                    .frame(width: 320, height: 200)
            }
    }
    .paperTheme(.cream)
}

#Preview("TornEdgeShape · Kraft") {
    ZStack {
        BookCover()
        TornEdgeShape()
            .fill(PaperTheme.kraft.cream)
            .frame(width: 320, height: 200)
    }
    .paperTheme(.kraft)
}

#Preview("TornEdgeShape · Midnight") {
    ZStack {
        BookCover()
        TornEdgeShape()
            .fill(PaperTheme.midnight.cream)
            .frame(width: 320, height: 200)
    }
    .paperTheme(.midnight)
}
