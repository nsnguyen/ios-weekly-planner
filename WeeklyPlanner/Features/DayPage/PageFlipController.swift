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
/// new flip requests. The view layer calls `commit()` after the animation
/// duration to finalize the transition; if it never does, the controller's
/// own `autoCommitDelay` fallback finalizes it so a flip can never strand.
///
/// This type is `@MainActor` because it's driven directly from SwiftUI view
/// updates and gesture callbacks.
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

    /// Set by `AIStickyStack` during an active swipe gesture so the
    /// page-level `HorizontalSwipeGesture` can yield to it.
    var stickyDragActive = false

    /// Maximum time a flip may stay un-committed before the controller
    /// force-commits itself.
    ///
    /// This is the Phase 27 freeze fix. Before it, `commit()` was driven
    /// *only* by `PageFlipContainer.onChange(of:)` — which exists only in the
    /// Day view. A flip started anywhere without that container (e.g. the Week
    /// view's `flipWeek`) set `target` with no committer, so `isFlipping`
    /// (`target != nil`) stranded permanently and every subsequent
    /// `flipDay`/`flipToDay`/`flipWeek`/`setWeek` no-oped — the app froze.
    ///
    /// The fallback guarantees `target` can never stay non-nil forever. It is
    /// set just above the 620ms day-page flip animation so the view's own
    /// `commit()` normally fires first; when it does, this fallback finds
    /// `target == nil` and no-ops (`commit()` is idempotent).
    private let autoCommitDelay: Duration

    /// The in-flight fallback-commit task, if any. Cancelled by `commit()` and
    /// `cancel()` so it can never double-fire or finalize a stale flip.
    private var pendingCommit: Task<Void, Never>?

    /// Designated initializer.
    ///
    /// Kept as a single `current:` parameter (no defaulted second argument) so
    /// its mangled symbol is unchanged — existing callers keep linking without
    /// a full rebuild. The fallback delay defaults to 700ms (just above the
    /// flip animation).
    ///
    /// - Parameter current: The page the user starts on.
    init(current: PageCoordinate) {
        self.current = current
        self.autoCommitDelay = .milliseconds(700)
    }

    /// Test seam: inject a short fallback delay to exercise the auto-commit
    /// path deterministically. Production always uses `init(current:)`.
    ///
    /// - Parameters:
    ///   - current: The page the user starts on.
    ///   - autoCommitDelay: Safety-net delay after which an un-committed flip
    ///     force-commits.
    init(current: PageCoordinate, autoCommitDelay: Duration) {
        self.current = current
        self.autoCommitDelay = autoCommitDelay
    }

    /// Schedule the fallback commit for the current flip, replacing any prior
    /// pending one. The `Task.isCancelled` guard after the sleep means a
    /// view-driven `commit()`/`cancel()` (which cancels this task) prevents a
    /// double or stale commit; if nothing cancels it, the flip still resolves.
    private func scheduleAutoCommit() {
        pendingCommit?.cancel()
        let delay = autoCommitDelay
        pendingCommit = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.commit()
        }
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
        scheduleAutoCommit()
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
        scheduleAutoCommit()
    }

    /// Advance the current coordinate by one whole week. Keeps the same day
    /// index.
    ///
    /// - Parameter direction: Direction to flip toward. `.next` advances the
    ///   week by 1, `.prev` rewinds by 1.
    func flipWeek(direction: FlipDirection) {
        guard !isFlipping else { return }
        let nextWeek = direction == .next ? current.week + 1 : current.week - 1
        target = PageCoordinate(week: nextWeek, day: current.day)
        self.direction = direction
        progress = 0
        scheduleAutoCommit()
    }

    /// Instantly set the week (no flip animation, no target). Used by the week
    /// chevrons (Day *and* Week view) and the week picker: "shifts weekOffset
    /// without triggering the page-flip animation". Because it mutates
    /// `current` directly and never sets `target`, it can never strand
    /// `isFlipping`.
    ///
    /// - Parameter week: New week offset (relative to today's week). The day
    ///   index is preserved.
    func setWeek(_ week: Int) {
        guard !isFlipping else { return }
        current = PageCoordinate(week: week, day: current.day)
    }

    /// Finalize the transition. Called by the view when the animation
    /// completes (and by the `autoCommitDelay` fallback). Sets
    /// `current = target`, clears `target`/`direction`, resets `progress`, and
    /// cancels any pending fallback. No-op when there is no in-flight flip.
    func commit() {
        pendingCommit?.cancel()
        pendingCommit = nil
        guard let target else { return }
        current = target
        self.target = nil
        direction = nil
        progress = 0
    }

    /// Cancel an in-progress flip (e.g., user lifted finger before the
    /// commit threshold). Resets `target`, `direction`, and `progress`
    /// without moving `current`, and cancels any pending fallback.
    func cancel() {
        pendingCommit?.cancel()
        pendingCommit = nil
        target = nil
        direction = nil
        progress = 0
    }
}
