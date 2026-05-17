import SwiftUI

/// Bottom-trailing corner curl that suggests a folded-up page corner.
///
/// A 28x28pt square clipped to a right-triangle (vertices at top-leading,
/// bottom-leading, bottom-trailing), filled with a 135° linear gradient that
/// is transparent through the first half and then steps to a translucent black
/// for the bottom-right corner. The bottom-trailing corner is rounded to
/// match the page surface, the rest of the square is square so the triangle
/// nestles flush against the bottom and right edges of its host.
///
/// Layering role: top-most decorative layer on a `BookPage`, after the
/// `BindingShadow`. Pure decoration — `.allowsHitTesting(false)` so it never
/// intercepts taps.
struct PageCurl: View {
    /// Side length of the curl (matches the mock).
    private static let size: CGFloat = 28

    /// Corner radius on the bottom-trailing corner, matching the page surface.
    private static let cornerRadius: CGFloat = 12

    var body: some View {
        let gradientPoints = CSSGradientAngle.unitPoints(degrees: 135)
        let gradient = LinearGradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .clear, location: 0.5),
            .init(color: Color.black.opacity(0.08), location: 0.5),
            .init(color: Color.black.opacity(0.18), location: 1.0),
        ],
        startPoint: gradientPoints.start,
        endPoint: gradientPoints.end)

        gradient
            .frame(width: Self.size, height: Self.size)
            .clipShape(CurlTriangle())
            .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0,
                                                                 bottomLeading: 0,
                                                                 bottomTrailing: Self.cornerRadius,
                                                                 topTrailing: 0)))
            .allowsHitTesting(false)
    }
}

/// Right-triangle with vertices at top-leading, bottom-leading, bottom-trailing.
/// Defined here (not as a generic `Triangle`) so a future shared `Triangle`
/// shape in Group B/D can be added without colliding with this one.
private struct CurlTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("PageCurl · Cream") {
    ZStack(alignment: .bottomTrailing) {
        BookCover()
        Color.white.opacity(0.9)
            .frame(width: 200, height: 200)
            .overlay(alignment: .bottomTrailing) {
                PageCurl()
            }
    }
    .paperTheme(.cream)
}

#Preview("PageCurl · Kraft") {
    ZStack(alignment: .bottomTrailing) {
        BookCover()
        Color(hex: "#E6D2A8")
            .frame(width: 200, height: 200)
            .overlay(alignment: .bottomTrailing) {
                PageCurl()
            }
    }
    .paperTheme(.kraft)
}

#Preview("PageCurl · Midnight") {
    ZStack(alignment: .bottomTrailing) {
        BookCover()
        Color(hex: "#1E1F2D")
            .frame(width: 200, height: 200)
            .overlay(alignment: .bottomTrailing) {
                PageCurl()
            }
    }
    .paperTheme(.midnight)
}
