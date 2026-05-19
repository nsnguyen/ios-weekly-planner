import Foundation

/// Deterministic, framework-free `IntelligenceService` implementation.
///
/// Doubles as both the test double for unit tests and the runtime
/// fallback when `PlannerLanguageModel` reports unavailable (older device,
/// user disabled, model not ready). The body strings come from the same
/// `AISearchCannedData` table that Phase 12 already ships, so the fallback
/// UX matches what users saw before Phase 13.
@MainActor
final class StubIntelligenceService: IntelligenceService {
    private let eventStore: any EventStoring
    private let clock: () -> Date

    init(eventStore: any EventStoring, clock: @escaping () -> Date = { Date() }) {
        self.eventStore = eventStore
        self.clock = clock
    }

    func availability(context: PlannerContext) async -> AvailabilityState {
        if !context.appleIntelligenceEnabled {
            return .unavailable(.userDisabled)
        }
        return .available
    }

    func ask(query: String, context: PlannerContext) async throws -> AIAnswer {
        let sanitized = SafetyGuard.sanitize(query)
        let canned = AISearchCannedData.canned(for: sanitized)
        let citations = await resolveCitations(titleHints: canned.titleHints, now: clock())
        return AIAnswer(
            query: sanitized,
            body: canned.body,
            citations: citations,
            actions: canned.actions,
            elapsedSeconds: 0
        )
    }

    /// Internal so `PlannerLanguageModel` can reuse the same title-substring
    /// match for citation chips on real model answers.
    func resolveCitations(titleHints: [String], now: Date) async -> [AICitation] {
        guard !titleHints.isEmpty else { return [] }
        let lowered = titleHints.map { $0.lowercased() }
        var results: [AICitation] = []
        for weekOffset in -4 ... 4 {
            guard let events = try? await eventStore.events(forWeekOffset: weekOffset, today: now) else { continue }
            for event in events {
                let title = event.title.lowercased()
                guard lowered.contains(where: { title.contains($0) }) else { continue }
                results.append(AICitation(
                    id: event.id,
                    title: event.title,
                    category: event.category,
                    weekdayLong: Self.weekdayFormatter.string(from: event.start),
                    timeShort: Self.timeFormatter.string(from: event.start)
                ))
                if results.count >= 3 { return results }
            }
        }
        return results
    }

    /// Cheap heuristic used by `PlannerLanguageModel`: tokenize the model's
    /// answer body and look for any token longer than 3 chars in event
    /// titles within ±4 weeks.
    func resolveCitations(forBody body: String, now: Date) async -> [AICitation] {
        let tokens = body
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .filter { $0.count > 3 }
            .map(String.init)
        return await resolveCitations(titleHints: Array(Set(tokens)), now: now)
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
