import SwiftUI

/// A non-interactive shading layer that washes across a flipping page leaf,
/// peaking at the midpoint of the flip and fading out as the page lands.
/// The effect sells the illusion that the paper is catching less light as it
/// stands on its edge.
///
/// Opacity follows a sine curve: `sin(progress * π) * 0.55`. That gives
/// `0 → 0.55 → 0` across `progress 0.0 ... 0.5 ... 1.0`, which matches the
/// `0 → 0.55 → 0` keyframe envelope from
/// `docs/phases/phase-08-side-tabs-and-flip.md`.
///
/// The gradient direction depends on the flip direction. For `.next` the
/// trailing (outer) edge darkens first because that's the side the leaf folds
/// toward; for `.prev` the gradient is mirrored. The overlay has hit-testing
/// disabled so it never swallows taps from underlying paper content.
struct PageShadeOverlay: View {
    /// Normalized flip progress, expected in `0.0 ... 1.0`. Values outside
    /// that range are tolerated — the sine envelope simply continues — but
    /// callers should keep it inside the unit interval.
    let progress: Double

    /// Which direction the parent page is flipping. Determines which side of
    /// the gradient is the dark side.
    let direction: FlipDirection

    var body: some View {
        let alpha = sin(progress * .pi) * 0.55
        gradient
            .opacity(alpha)
            .allowsHitTesting(false)
    }

    /// The underlying linear gradient. For `.next` the trailing side is the
    /// dark end (the leaf folds outward to the right, so its rightmost edge
    /// is in shadow). For `.prev` the same gradient is mirrored.
    private var gradient: LinearGradient {
        switch direction {
        case .next:
            LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.18)],
                           startPoint: .leading,
                           endPoint: .trailing)
        case .prev:
            LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.18)],
                           startPoint: .trailing,
                           endPoint: .leading)
        }
    }
}

// MARK: - Previews

#Preview("PageShadeOverlay · mid-flip next") {
    ZStack {
        Color(red: 0.97, green: 0.93, blue: 0.85)
        PageShadeOverlay(progress: 0.5, direction: .next)
    }
    .frame(width: 320, height: 480)
}

#Preview("PageShadeOverlay · mid-flip prev") {
    ZStack {
        Color(red: 0.97, green: 0.93, blue: 0.85)
        PageShadeOverlay(progress: 0.5, direction: .prev)
    }
    .frame(width: 320, height: 480)
}
