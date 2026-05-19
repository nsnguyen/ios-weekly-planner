import Foundation

/// Per-request execution context handed to `IntelligenceService` and its
/// tools. Carries enough state for a tool call to scope its search without
/// any tool reaching back into global singletons.
///
/// Value-typed and `Sendable` so it can cross actor hops cleanly.
struct PlannerContext: Sendable {
    /// "Now" for week-math and last-interaction queries. Injected so tests
    /// can pin a deterministic Saturday-May-16 anchor.
    let now: Date

    /// Week the user is currently viewing (relative to the week containing
    /// `now`). Lets the model bias date-range tool calls toward what's on
    /// screen.
    let viewedWeekOffset: Int

    /// Hard upper bound on tokens for the model's reply. Different surfaces
    /// pass different values: 256 for the search overlay, 120 for stickies.
    let maxResponseTokens: Int

    /// Whether Apple Intelligence is enabled in `UserSettings`. The service
    /// re-checks this every call so a Settings flip doesn't need a restart.
    let appleIntelligenceEnabled: Bool

    /// Default tuned for the AI overlay.
    static let `default` = PlannerContext(
        now: .init(),
        viewedWeekOffset: 0,
        maxResponseTokens: 256,
        appleIntelligenceEnabled: true
    )
}
