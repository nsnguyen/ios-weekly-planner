import Foundation

/// Per-week AI-generated reflection used by the Review page (Phase 14)
/// and any future surface that wants a one-paragraph summary + structured
/// bullets. Value-typed and Sendable so it can flow across actor hops and
/// be cached in memory without copy hazards.
struct WeekSummary: Equatable, Sendable {
    /// One-paragraph handwritten body shown in the blue-ink "AI SUMMARY"
    /// block. Two to three sentences; matches the Phase 13 system prompt's
    /// length contract.
    let headline: String

    /// Star-bullet rows shown in the "Notes from AI" list. Each carries
    /// its ink color so the view layer can paint the ★ + text in the
    /// matching tone.
    let bullets: [Bullet]

    /// 0.0–1.0 share of the week's tasks that were completed. Driven by
    /// the actual task data, not the model — kept on `WeekSummary` so
    /// callers don't have to thread it separately.
    let completionPercent: Double

    struct Bullet: Equatable, Sendable {
        /// Visible text — handwritten 16pt body.
        let text: String
        /// Ink color the bullet (★ + text) renders in.
        let ink: Ink
    }

    enum Ink: String, Equatable, Sendable {
        /// Default ink — neutral.
        case dark
        /// Encouragement / positive trend.
        case green
        /// Warning / overdue / unbooked.
        case red
        /// Reference / cross-link.
        case blue
    }
}

// Phase 32 (#38): the old `WeekSummary.fallback(...)` extension was removed.
// It fabricated content ("kept Wednesday's run", "Sara's gift", canned
// bullets) that rendered as if it were real AI output. The Review page now
// degrades honestly via `WeekSummaryOutcome` / `ReviewViewModel.SummaryState`.
