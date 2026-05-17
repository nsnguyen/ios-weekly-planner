import SwiftUI

/// Soft shadow at the leading edge of a page suggesting the binding curves
/// inward. Renders a 24pt-wide horizontal linear gradient from
/// `rgba(0,0,0,0.32)` at the leading edge to `rgba(0,0,0,0)` at the trailing
/// edge of the strip.
///
/// Layering role: sits ON TOP of the page surface (z-index 6 in the mock),
/// so the shadow falls onto the page content rather than onto the spine.
/// `.allowsHitTesting(false)` so it never blocks taps on content underneath.
struct BindingShadow: View {
    /// Width of the gradient strip.
    private static let width: CGFloat = 24

    var body: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [Color.black.opacity(0.32), Color.black.opacity(0)],
                           startPoint: .leading,
                           endPoint: .trailing)
                .frame(width: Self.width)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
    }
}

#Preview("BindingShadow · Cream") {
    ZStack {
        BookCover()
        ZStack(alignment: .leading) {
            Color(hex: "#FAF6E9")
            BindingShadow()
        }
        .frame(width: 300, height: 480)
    }
    .paperTheme(.cream)
}

#Preview("BindingShadow · Kraft") {
    ZStack {
        BookCover()
        ZStack(alignment: .leading) {
            Color(hex: "#E6D2A8")
            BindingShadow()
        }
        .frame(width: 300, height: 480)
    }
    .paperTheme(.kraft)
}

#Preview("BindingShadow · Midnight") {
    ZStack {
        BookCover()
        ZStack(alignment: .leading) {
            Color(hex: "#1E1F2D")
            BindingShadow()
        }
        .frame(width: 300, height: 480)
    }
    .paperTheme(.midnight)
}
