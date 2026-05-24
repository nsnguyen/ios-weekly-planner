import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Structured output from the keyword-insight Foundation Models prompt.
/// Non-optional `relatedEventID` uses empty-string as the "no related
/// event" sentinel — Phase 18 retro found that `Optional<String>`
/// fields cause the model to skip them silently. Always-present with
/// "" semantics works reliably.
struct KeywordInsightDraft: Sendable {
    let text: String
    let relatedEventID: String
    let confidence: Double
}

/// Seam over Foundation Models so unit tests inject a fake without
/// linking the real `LanguageModelSession`. Production impl lives below
/// (`LiveKeywordInsightModel`).
@MainActor
protocol KeywordInsightModeling {
    func generateKeyword(prompt: String, day: DayContext) async throws -> KeywordInsightDraft?
}

/// Foundation Models-backed keyword sticky generator. Reads the day's
/// event titles, asks the on-device model for one short nudge tied to a
/// notable detail (birthday / anniversary / deadline / named person),
/// and emits a `.keyword` insight when the model's confidence ≥ 0.6.
@MainActor
final class KeywordInsightGenerator: InsightGenerator {
    let kind: InsightKind = .keyword

    private let model: any KeywordInsightModeling
    private let confidenceThreshold: Double

    private static func tilt(weekOffset: Int, dayIdx: Int) -> Double {
        let hash = abs(weekOffset &* 31 &+ dayIdx)
        return Double(hash % 11) - 5.0
    }

    init(model: any KeywordInsightModeling, confidenceThreshold: Double = 0.6) {
        self.model = model
        self.confidenceThreshold = confidenceThreshold
    }

    func generate(for day: DayContext) async -> AIInsight? {
        guard day.appleIntelligenceEnabled else { return nil }
        guard !day.events.isEmpty else { return nil }

        let prompt = Self.prompt(events: day.events)
        let draft: KeywordInsightDraft?
        do {
            draft = try await model.generateKeyword(prompt: prompt, day: day)
        } catch {
            return nil
        }

        guard let d = draft,
              d.confidence >= confidenceThreshold,
              !d.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        let actionURL: String? = d.relatedEventID.isEmpty
            ? nil
            : "weeklyplanner://event/\(d.relatedEventID)"

        return AIInsight(
            dayKey: day.dayKey,
            dateGenerated: day.now,
            text: String(d.text.prefix(60)),
            colorHex: InsightKind.keyword.colorHex,
            tiltDegrees: Self.tilt(weekOffset: day.weekOffset, dayIdx: day.dayIdx),
            kind: .keyword,
            actionURL: actionURL,
            priority: InsightKind.keyword.defaultPriority
        )
    }

    /// Pure prompt builder — exposed for tests so the wording stays
    /// stable across edits. Lists the day's event titles + times and
    /// asks for at most one notable nudge.
    static func prompt(events: [Event]) -> String {
        var lines = [
            "Given today's events, generate at most one short, encouraging nudge that references a meaningful detail (birthday, anniversary, deadline, named person). Skip if nothing notable. Stay ≤ 60 chars, no emoji.",
            "Format the response as JSON: {\"text\":\"...\",\"relatedEventID\":\"<event uuid or empty>\",\"confidence\":0.0..1.0}",
            "Today's events:",
        ]
        for event in events.prefix(8) {
            lines.append("- \(event.id.uuidString): \(event.title)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Live Foundation Models implementation

/// Real Foundation Models implementation. Gated on iOS 26+ and the
/// `FoundationModels` SDK being available — falls through to `nil`
/// otherwise so the orchestrator simply skips this generator.
@MainActor
final class LiveKeywordInsightModel: KeywordInsightModeling {
    func generateKeyword(prompt: String, day _: DayContext) async throws -> KeywordInsightDraft? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            // The actual @Generable struct lives here; the Phase 18 pattern
            // is to define it alongside the live call so the FoundationModels
            // import stays local. We re-parse the JSON via JSONDecoder
            // because Generable + AIInsight cross-type pinning is brittle.
            let session = LanguageModelSession()
            do {
                let response = try await session.respond(to: prompt)
                let text = String(describing: response.content)
                guard let data = text.data(using: .utf8) else { return nil }
                let decoded = try JSONDecoder().decode(WireKeywordDraft.self, from: data)
                return KeywordInsightDraft(text: decoded.text,
                                            relatedEventID: decoded.relatedEventID,
                                            confidence: decoded.confidence)
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}

private struct WireKeywordDraft: Codable {
    let text: String
    let relatedEventID: String
    let confidence: Double
}
