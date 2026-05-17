import SwiftUI

/// Named animation curves and durations. Every transition in the app
/// references one of these — never inline `.easeInOut(duration:)`.
///
/// SwiftUI's `Animation.timingCurve` takes the same `cubic-bezier(p1x, p1y, p2x, p2y)`
/// control points as CSS, so values port 1-to-1 from the mock CSS.
enum AnimationTokens {
    /// The headline page-flip transition: 0.62s, ease-in-out S-curve.
    static let pageFlip = Animation.timingCurve(0.45, 0.05, 0.55, 0.95, duration: 0.62)

    /// Bottom-sheet slide-up (Settings, Event Detail).
    static let sheetSlide = Animation.timingCurve(0.20, 0.80, 0.20, 1.00, duration: 0.32)

    /// AI sticky-note peel animation. p2y > 1 produces a controlled overshoot
    /// at the end — note "lifts off" the page.
    static let stickyPeel = Animation.timingCurve(0.20, 0.80, 0.20, 1.10, duration: 0.32)

    /// Week-picker drop-down from the top bar.
    static let pickerDrop = Animation.timingCurve(0.20, 0.80, 0.20, 1.00, duration: 0.32)

    /// Faster fade applied to picker contents inside the drop.
    static let pickerFade = Animation.easeOut(duration: 0.20)

    /// "Thinking…" shimmer over the AI overlay. Looping linear sweep used as
    /// the duration for a repeating `linearGradient` animation in Phase 12.
    static let aiThinkingShimmerDuration: Double = 2.5
}
