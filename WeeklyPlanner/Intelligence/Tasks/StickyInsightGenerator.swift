import Foundation
import SwiftData

/// Produces the per-day handwritten sticky note that lives in the top-right
/// of the Day page. Builds a tiny prompt summarising the day's events and
/// asks the `IntelligenceService` for one short, encouraging line.
///
/// The generator does NOT persist the resulting `AIInsight` — callers (the
/// `DayPageViewModel`) own the SwiftData insert so the model context stays
/// inside the page's actor. Returns `nil` whenever the model is unavailable
/// or refuses, so callers fall back to the seeded insight (if any).
@MainActor
final class StickyInsightGenerator {
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

    /// Builds an `AIInsight` for the given day. Returns `nil` if AI is
    /// off, the model is unavailable, or the response is empty.
    func generate(weekOffset: Int,
                  dayIdx: Int,
                  events: [Event],
                  now: Date) async -> AIInsight?
    {
        let context = PlannerContext(
            now: now,
            viewedWeekOffset: weekOffset,
            maxResponseTokens: 80,
            appleIntelligenceEnabled: settings()
        )
        let availability = await intelligence.availability(context: context)
        guard availability.isAvailable else { return nil }

        let prompt = Self.prompt(weekOffset: weekOffset, dayIdx: dayIdx, events: events)
        do {
            let answer = try await intelligence.ask(query: prompt, context: context)
            let trimmed = answer.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            // Cap at 80 characters per spec. Truncates mid-word as a last
            // resort; the system prompt asks the model to stay short.
            let clamped = trimmed.count <= 80 ? trimmed : String(trimmed.prefix(80))
            let color = Self.color(weekOffset: weekOffset, dayIdx: dayIdx)
            let tilt = Self.tilt(weekOffset: weekOffset, dayIdx: dayIdx)
            return AIInsight(
                dayKey: AIInsight.key(weekOffset: weekOffset, dayIdx: dayIdx),
                dateGenerated: now,
                text: clamped,
                colorHex: color,
                tiltDegrees: tilt
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

    /// Deterministic color selection so the same (weekOffset, dayIdx) is
    /// always the same color across days even after the sticky regenerates.
    static func color(weekOffset: Int, dayIdx: Int) -> String {
        let hash = abs(weekOffset &* 7 &+ dayIdx)
        return palette[hash % palette.count]
    }

    /// Deterministic tilt in [-5, 5] degrees. Same hashing scheme as the
    /// color picker so a day's sticky has a stable look across regenerations.
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
