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

extension WeekSummary {
    /// Canned fallback used when the AI model is unavailable. Matches the
    /// strings called out in the Phase 14 spec's "default fallback" notes
    /// so the page never renders empty.
    static func fallback(weekOffset: Int, tasksDone: Int, tasksTotal: Int) -> WeekSummary {
        let pct = tasksTotal == 0 ? 0.0 : Double(tasksDone) / Double(tasksTotal)
        let headline = "A balanced week. You wrapped up \(tasksDone) of \(tasksTotal) tasks, "
            + "kept Wednesday's run, and still owe Sara her gift."
        return WeekSummary(
            headline: headline,
            bullets: [
                .init(text: "Health is up 40% this week. Keep it.", ink: .green),
                .init(text: "Friday afternoon — nothing booked. Block focus.", ink: .red),
                .init(text: "Sara's gift still on the list. Today!", ink: .red),
            ],
            completionPercent: pct
        )
    }
}
