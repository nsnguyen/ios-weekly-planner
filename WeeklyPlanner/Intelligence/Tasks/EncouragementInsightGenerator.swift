import Foundation

/// Fallback "one short encouraging line" sticky generator. Renamed from
/// Phase 13's `StickyInsightGenerator` and demoted to a fallback role
/// in Phase 24's cascade — runs only when the orchestrator's four
/// primary generators (travel / weather / keyword / inbox) all return
/// `nil`. Same Foundation Models prompt as before; same color/tilt math.
///
/// Conforms to the Phase 24 `InsightGenerator` protocol so the
/// orchestrator can drive it identically to the others; the `kind` is
/// always `.encouragement` and `priority` is `9` (the fallback floor).
@MainActor
final class EncouragementInsightGenerator: InsightGenerator {
    let kind: InsightKind = .encouragement

    private let intelligence: any IntelligenceService
    private let settings: () -> Bool

    /// Allowed sticky paper colors. Picked deterministically from the
    /// `(weekOffset, dayIdx)` pair so the same day always gets the same
    /// color, but different days have variety across the week.
    private static let palette = ["#FFE680", "#C9F0E0", "#FFCCC9"]

    init(intelligence: any IntelligenceService,
         settings: @escaping () -> Bool = { true })
    {
        self.intelligence = intelligence
        self.settings = settings
    }

    func generate(for day: DayContext) async -> AIInsight? {
        guard day.appleIntelligenceEnabled else { return nil }

        let context = PlannerContext(
            now: day.now,
            viewedWeekOffset: day.weekOffset,
            maxResponseTokens: 80,
            appleIntelligenceEnabled: day.appleIntelligenceEnabled
        )
        let availability = await intelligence.availability(context: context)
        guard availability.isAvailable else { return nil }

        let prompt = Self.prompt(weekOffset: day.weekOffset,
                                  dayIdx: day.dayIdx,
                                  events: day.events)
        do {
            let answer = try await intelligence.ask(query: prompt, context: context)
            let trimmed = answer.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let clamped = trimmed.count <= 80 ? trimmed : String(trimmed.prefix(80))
            return AIInsight(
                dayKey: day.dayKey,
                dateGenerated: day.now,
                text: clamped,
                colorHex: Self.color(weekOffset: day.weekOffset, dayIdx: day.dayIdx),
                tiltDegrees: Self.tilt(weekOffset: day.weekOffset, dayIdx: day.dayIdx),
                kind: .encouragement,
                actionURL: nil,
                priority: InsightKind.encouragement.defaultPriority
            )
        } catch {
            return nil
        }
    }

    /// Pure prompt builder. Exposed for tests so the prompt shape stays
    /// stable across edits.
    static func prompt(weekOffset: Int, dayIdx: Int, events: [Event]) -> String {
        let dayName = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][min(max(dayIdx, 0), 6)]
        var lines = [
            "Write one short, encouraging, handwritten-style note (≤ 80 chars, no emoji) about the user's plans for \(dayName).",
        ]
        if events.isEmpty {
            lines.append("There are no events scheduled.")
        } else {
            lines.append("Today's events:")
            for event in events.prefix(5) {
                let time = Self.timeFormatter.string(from: event.start)
                lines.append("- \(time): \(event.title)")
            }
        }
        lines.append("Reply with just the note — no preamble, no quotes.")
        return lines.joined(separator: "\n")
    }

    static func color(weekOffset: Int, dayIdx: Int) -> String {
        let hash = abs(weekOffset &* 7 &+ dayIdx)
        return palette[hash % palette.count]
    }

    static func tilt(weekOffset: Int, dayIdx: Int) -> Double {
        let hash = abs(weekOffset &* 31 &+ dayIdx)
        return Double(hash % 11) - 5.0
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
