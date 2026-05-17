import Foundation
import Observation

/// Direction of an in-flight page flip.
///
/// `.next` advances the calendar forward (Mon → Tue, Sun → next-week Mon),
/// `.prev` walks backward (Mon → prev-week Sun, Tue → Mon).
enum FlipDirection: Equatable {
    /// Flipping toward a later day.
    case next
    /// Flipping toward an earlier day.
    case prev
}

/// Identifier for a single Day page in the planner.
///
/// `week` is a relative offset from "today's week" (0 = current, +1 = next,
/// -1 = previous). `day` is a Monday-based weekday index `0...6`
/// (0 = Mon … 6 = Sun) matching the rest of the app's week math.
struct PageCoordinate: Equatable, Hashable {
    /// Week offset relative to "today's week".
    let week: Int
    /// Monday-based weekday index, `0...6`.
    let day: Int
}

/// Drives the 3D page-flip animation. Holds three pieces of state:
/// - `current`: the page the user is on right now (post-flip).
/// - `target`: the page being flipped to. `nil` when idle.
/// - `direction`: which way we're flipping; `nil` when idle.
///
/// While `target != nil` the view is mid-flip and the controller refuses
/// new flip requests. Callers call `commit()` after the animation duration
/// to finalize the transition (or wait for the controller's own timer).
///
/// This type is `@MainActor` because it's driven directly from SwiftUI view
/// updates and gesture callbacks; it does not perform any animation timing
/// itself — the view layer schedules the timed `commit()` call.
@MainActor
@Observable
final class PageFlipController {
    /// The page currently visible to the user. After `commit()` this equals
    /// the page that was just flipped to.
    private(set) var current: PageCoordinate

    /// The page being flipped toward. `nil` while idle.
    private(set) var target: PageCoordinate?

    /// Direction of the active flip. `nil` while idle.
    private(set) var direction: FlipDirection?

    /// Visible-progress hint for the view layer (0...1). Updated by the
    /// view's animation driver. The controller itself doesn't time the
    /// animation; this is a write-through value SwiftUI can observe.
    var progress: Double = 0

    /// True iff a flip is currently in progress.
    var isFlipping: Bool {
        target != nil
    }

    /// Designated initializer.
    ///
    /// - Parameter current: The page the user starts on.
    init(current: PageCoordinate) {
        self.current = current
    }

    /// Start a flip in the given direction. No-op while already flipping.
    ///
    /// Week-crossing rules:
    /// - `.next` on `day == 6` (Sunday) advances to `(week + 1, 0)`.
    /// - `.prev` on `day == 0` (Monday) walks back to `(week - 1, 6)`.
    ///
    /// - Parameter direction: Direction to flip toward.
    func flipDay(direction: FlipDirection) {
        guard !isFlipping else { return }

        let next = switch direction {
        case .next:
            if current.day == 6 {
                PageCoordinate(week: current.week + 1, day: 0)
            } else {
                PageCoordinate(week: current.week, day: current.day + 1)
            }
        case .prev:
            if current.day == 0 {
                PageCoordinate(week: current.week - 1, day: 6)
            } else {
                PageCoordinate(week: current.week, day: current.day - 1)
            }
        }

        target = next
        self.direction = direction
        progress = 0
    }

    /// Flip directly to a specific day index in the *current* week.
    /// Direction is inferred from `idx` vs `current.day`. If `idx == current.day`,
    /// no-op.
    ///
    /// - Parameter idx: Monday-based weekday index. Clamped to `0...6` for
    ///   defensiveness — out-of-range inputs are pinned to the nearest valid
    ///   index rather than crashing.
    func flipToDay(idx: Int) {
        let clamped = min(max(idx, 0), 6)
        guard !isFlipping else { return }
        guard clamped != current.day else { return }

        target = PageCoordinate(week: current.week, day: clamped)
        direction = clamped > current.day ? .next : .prev
        progress = 0
    }

    /// Advance the current coordinate by one whole week. Keeps the same day
    /// index. Used by the top-bar week chevrons (in Week view) and by the
    /// Week page's swipe gesture.
    ///
    /// - Parameter direction: Direction to flip toward. `.next` advances the
    ///   week by 1, `.prev` rewinds by 1.
    func flipWeek(direction: FlipDirection) {
        guard !isFlipping else { return }
        let nextWeek = direction == .next ? current.week + 1 : current.week - 1
        target = PageCoordinate(week: nextWeek, day: current.day)
        self.direction = direction
        progress = 0
    }

    /// Instantly set the week (no flip animation, no target). Used by the Day
    /// view's chevrons per spec: "shifts weekOffset by ±1 without triggering
    /// the page-flip animation".
    ///
    /// - Parameter week: New week offset (relative to today's week). The day
    ///   index is preserved.
    func setWeek(_ week: Int) {
        guard !isFlipping else { return }
        current = PageCoordinate(week: week, day: current.day)
    }

    /// Finalize the transition. Called by the view when the animation
    /// completes. Sets `current = target`, clears `target` and `direction`,
    /// and resets `progress` to 0. No-op when there is no in-flight flip.
    func commit() {
        guard let target else { return }
        current = target
        self.target = nil
        direction = nil
        progress = 0
    }

    /// Cancel an in-progress flip (e.g., user lifted finger before the
    /// commit threshold). Resets `target`, `direction`, and `progress`
    /// without moving `current`.
    func cancel() {
        target = nil
        direction = nil
        progress = 0
    }
}
