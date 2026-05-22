import SwiftUI

/// A reusable horizontal-drag gesture modifier that reports a committed swipe
/// direction via a callback. Used by `DayPageView` to translate a finger-flick
/// across the page into a `PageFlipController.flipDay(direction:)` call.
///
/// The gesture is attached as a `.simultaneousGesture` so it never blocks
/// children (taps on the side tabs, todo rows, etc. still register normally).
/// It only fires `onSwipe` at the end of a drag, never mid-drag — visual
/// "lean" during a drag is intentionally the caller's concern, not the
/// gesture's. The recognizer also discards vertical-dominant drags so the
/// future Phase 12 vertical AI-pull gesture remains free to use the same
/// region.
///
/// Commit threshold is 40pt by default, matching the spec in
/// `docs/phases/phase-08-side-tabs-and-flip.md`. Below the threshold the
/// gesture is a no-op (the page snaps back to its resting state).
struct HorizontalSwipeGesture: ViewModifier {
    /// Minimum horizontal translation, in points, required before a drag is
    /// treated as a commit. Defaults to 40pt — the value pinned in the spec.
    var threshold: CGFloat = 40

    /// Invoked exactly once per drag, at `.onEnded`, when the drag exceeded
    /// the threshold and was horizontally dominant. Not called for vertical
    /// drags or short drags.
    var onSwipe: (FlipDirection) -> Void

    /// Live horizontal offset for callers that want to read the drag for a
    /// visual lean. Currently unused by the gesture itself; it's tracked so
    /// future polish (Phase 22) can attach a `.rotation3DEffect` proportional
    /// to it without changing the gesture's public contract.
    @State private var dragOffset: CGFloat = 0

    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(DragGesture(minimumDistance: 10)
                .onChanged { value in
                    dragOffset = RTLMath.adjustDeltaX(value.translation.width, for: layoutDirection)
                }
                .onEnded { value in
                    dragOffset = 0
                    let dx = RTLMath.adjustDeltaX(value.translation.width, for: layoutDirection)
                    let dy = value.translation.height
                    // Vertical-dominant drags are ignored entirely so
                    // future vertical gestures stay clear.
                    guard abs(dx) > abs(dy) else { return }
                    if dx < -threshold {
                        onSwipe(.next)
                    } else if dx > threshold {
                        onSwipe(.prev)
                    }
                })
    }
}

extension View {
    /// Attach a horizontal-swipe recognizer that calls `onSwipe(.next)` when
    /// the user flicks leftward past the 40pt threshold and `onSwipe(.prev)`
    /// when they flick rightward past it. Vertical-dominant drags are
    /// ignored, and the underlying `DragGesture` is `.simultaneousGesture`
    /// so child tap targets keep working.
    func horizontalSwipe(onSwipe: @escaping (FlipDirection) -> Void) -> some View {
        modifier(HorizontalSwipeGesture(onSwipe: onSwipe))
    }
}
