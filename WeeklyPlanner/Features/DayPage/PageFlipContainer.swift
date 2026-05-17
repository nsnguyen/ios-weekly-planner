import SwiftUI

/// Hosts the current and target Day page during a flip and drives the 3D
/// rotation animation. While idle (`controller.target == nil`) the container
/// is transparent — it just renders the current page and the layout doesn't
/// know there's a flip mechanism at all. While mid-flip it layers the
/// target page underneath and animates the current page out, swapping at the
/// midpoint so the user sees the destination page completing the arc.
///
/// ## Implementation note: simplified half-fold variant
///
/// This is the *simplified* half-fold variant of the spec's full
/// backface-mirroring flip. Instead of rendering both faces of a single leaf
/// and swapping based on `progress > 0.5`, we:
///
/// 1. Render the destination page underneath, unrotated, the whole time.
/// 2. Render the source page on top. For the first half of the flip
///    (`progress < 0.5`) it rotates from 0° toward ±90° around its hinge
///    edge — appearing to lift off the book.
/// 3. At `progress >= 0.5` we hide the source page entirely and bring the
///    destination page in, rotating it from ∓90° back to 0° — appearing to
///    settle down onto the book from the other side.
///
/// This avoids two SwiftUI sharp edges: `rotation3DEffect` does not support
/// backface culling, and getting a back-of-paper image to look right (without
/// the text rendering mirrored or upside-down) requires non-trivial layer
/// gymnastics. The half-fold reads convincingly as a paper flip in motion
/// and matches the spec's animation curve and duration. The full
/// backface-visibility flip is deferred to Phase 22 polish as called out in
/// `docs/phases/phase-08-side-tabs-and-flip.md`.
///
/// ## Reduce-motion path
///
/// When `\.accessibilityReduceMotion` is enabled the 3D rotation is replaced
/// by a 0.15s opacity crossfade, matching the accessibility behaviour spelled
/// out in the spec.
struct PageFlipContainer<Page: View>: View {
    /// The state machine for the in-flight (or idle) flip. The container is a
    /// pure renderer of this state — it does not initiate flips.
    let controller: PageFlipController

    /// Builder that produces the page content for a given coordinate. Called
    /// once for the current page while idle, and twice during a flip (once
    /// for the source, once for the destination). Both invocations are
    /// expected to be cheap; the inner view itself is responsible for
    /// stable identity via `.id(coord)`.
    @ViewBuilder let page: (PageCoordinate) -> Page

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Mirrors `controller.progress` but is animated by the view layer.
    /// Driving the progress through a view-local `@State` plus
    /// `withAnimation` lets SwiftUI interpolate between 0 and 1 over the
    /// `pageFlip` duration without having to schedule a CADisplayLink.
    @State private var progress: Double = 0

    var body: some View {
        ZStack {
            if controller.target == nil {
                // Idle: just the current page.
                pageView(for: controller.current)
            } else if let target = controller.target,
                      let direction = controller.direction
            {
                // Mid-flip: layered.
                if reduceMotion {
                    reduceMotionFlip(target: target)
                } else {
                    fullFlip(source: controller.current,
                             target: target,
                             direction: direction)
                }
            }
        }
        .onChange(of: controller.target) { _, newValue in
            guard newValue != nil else { return }
            // Reset the local progress, then animate to 1.0 with the page-flip
            // curve. Schedule a `commit()` after the animation duration so the
            // controller flips back to idle and the wrapping content rebuilds
            // around the new `current`.
            progress = 0
            controller.progress = 0
            let duration: Duration = reduceMotion
                ? .milliseconds(150)
                : .milliseconds(620)
            withAnimation(reduceMotion
                ? .linear(duration: 0.15)
                : AnimationTokens.pageFlip)
            {
                progress = 1
                controller.progress = 1
            }
            Task { @MainActor in
                try? await Task.sleep(for: duration)
                controller.commit()
                progress = 0
            }
        }
    }

    // MARK: - Subviews

    /// Wraps the builder output in an `.id(coord)` so SwiftUI rebuilds the
    /// inner view (and its `@State` view model) whenever the coordinate
    /// changes. Without this, swiping between days would reuse the existing
    /// `DayPageContent` instance and the view model would keep the wrong
    /// day's data on screen until its `.task` re-ran.
    private func pageView(for coord: PageCoordinate) -> some View {
        page(coord).id(coord)
    }

    /// Reduce-motion path: crossfade the destination in over 0.15s. The
    /// underlying source page is still drawn so the fade comes off as a true
    /// blend rather than a flash on top of an empty background.
    private func reduceMotionFlip(target: PageCoordinate) -> some View {
        ZStack {
            pageView(for: controller.current)
            pageView(for: target)
                .opacity(progress)
        }
    }

    /// The full 3D half-fold flip. See the type's doc comment for the
    /// implementation strategy.
    private func fullFlip(source: PageCoordinate,
                          target: PageCoordinate,
                          direction: FlipDirection) -> some View
    {
        let halfway = progress >= 0.5

        // Source page: visible during the first half, rotating from 0 to ±90°.
        // After halfway it's hidden so we don't see the "back" of the page
        // (which would be the same content mirrored — not what a paper flip
        // looks like).
        let sourceProgress = min(progress, 0.5) * 2.0 // 0 → 1 across 0...0.5
        let sourceAngle: Double = {
            let magnitude = sourceProgress * 90.0
            return direction == .next ? -magnitude : magnitude
        }()

        // Target page: visible during the second half, rotating from ∓90° to 0°.
        let targetProgress = max(progress - 0.5, 0) * 2.0 // 0 → 1 across 0.5...1
        let targetAngle: Double = {
            let magnitude = (1.0 - targetProgress) * 90.0
            return direction == .next ? magnitude : -magnitude
        }()

        let anchor: UnitPoint = direction == .next ? .leading : .trailing

        return ZStack {
            // Destination underneath, kept simple — it's only revealed past
            // the midpoint, but rendering it the whole time keeps SwiftUI's
            // view identity stable.
            pageView(for: target)
                .opacity(halfway ? 1 : 0)
                .rotation3DEffect(.degrees(targetAngle),
                                  axis: (x: 0, y: 1, z: 0),
                                  anchor: anchor,
                                  perspective: 1.0 / Spacing.pageFlipPerspective)
                .overlay(PageShadeOverlay(progress: progress, direction: direction)
                    .opacity(halfway ? 1 : 0))

            // Source on top, lifting off in the first half.
            pageView(for: source)
                .opacity(halfway ? 0 : 1)
                .rotation3DEffect(.degrees(sourceAngle),
                                  axis: (x: 0, y: 1, z: 0),
                                  anchor: anchor,
                                  perspective: 1.0 / Spacing.pageFlipPerspective)
                .overlay(PageShadeOverlay(progress: progress, direction: direction)
                    .opacity(halfway ? 0 : 1))
        }
    }
}
