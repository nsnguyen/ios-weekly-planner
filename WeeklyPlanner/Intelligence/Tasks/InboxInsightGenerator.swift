import Foundation

/// Counts pending `InboxSuggestion` rows for the day and emits a one-line
/// nudge ("3 inbox suggestions for today") that deep-links into the
/// Day page's inbox section. Synchronous (no AI, no network) — runs
/// first in the orchestrator's task group and almost always finishes
/// before the others.
///
/// Priority `3` puts inbox below travel / weather / keyword in the
/// cascade — it's the lowest-stakes nudge.
@MainActor
final class InboxInsightGenerator: InsightGenerator {
    let kind: InsightKind = .inbox

    /// Deterministic tilt math borrowed from `EncouragementInsightGenerator`
    /// so the inbox sticky doesn't sit perfectly flat (the paper aesthetic
    /// always tilts ±5°).
    private static func tilt(weekOffset: Int, dayIdx: Int) -> Double {
        let hash = abs(weekOffset &* 31 &+ dayIdx)
        return Double(hash % 11) - 5.0
    }

    func generate(for day: DayContext) async -> AIInsight? {
        let count = day.inbox.count
        guard count > 0 else { return nil }
        let body = count == 1
            ? "1 inbox suggestion for today"
            : "\(count) inbox suggestions for today"
        return AIInsight(
            dayKey: day.dayKey,
            dateGenerated: day.now,
            text: body,
            colorHex: InsightKind.inbox.colorHex,
            tiltDegrees: Self.tilt(weekOffset: day.weekOffset, dayIdx: day.dayIdx),
            kind: .inbox,
            actionURL: "weeklyplanner://inbox/\(day.dayKey)",
            priority: InsightKind.inbox.defaultPriority
        )
    }
}
