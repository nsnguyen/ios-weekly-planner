import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Concrete `IntelligenceService` that calls the on-device Apple Intelligence
/// model. Falls back to `StubIntelligenceService` whenever the system says
/// the model isn't currently usable. All Foundation-Models-specific work is
/// gated `@available(iOS 26.0, *)` so the rest of the app target builds on
/// any iOS 26 simulator (even those without the model file present).
@MainActor
final class PlannerLanguageModel: IntelligenceService {
    private let registry: ToolRegistry
    private let fallback: StubIntelligenceService
    private let clock: @Sendable () -> Date

    init(registry: ToolRegistry,
         fallback: StubIntelligenceService,
         clock: @escaping @Sendable () -> Date = { Date() })
    {
        self.registry = registry
        self.fallback = fallback
        self.clock = clock
    }

    func availability(context: PlannerContext) async -> AvailabilityState {
        if !context.appleIntelligenceEnabled {
            return .unavailable(.userDisabled)
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .unavailable(.deviceNotEligible)
            case .unavailable(.modelNotReady):
                return .unavailable(.modelNotReady)
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable(.appleIntelligenceNotEnabled)
            @unknown default:
                return .unavailable(.modelNotReady)
            }
        }
        #endif
        return .unavailable(.deviceNotEligible)
    }

    func ask(query: String, context: PlannerContext) async throws -> AIAnswer {
        let availability = await availability(context: context)
        guard availability.isAvailable else {
            return try await fallback.ask(query: query, context: context)
        }

        let sanitized = SafetyGuard.sanitize(query)

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let session = makeSession()
                let started = Date()
                let response = try await session.respond(to: sanitized)
                let elapsed = Date().timeIntervalSince(started)
                let body = response.content
                let citations = await resolveCitations(session: session, body: body)
                return AIAnswer(
                    query: sanitized,
                    body: body,
                    citations: citations,
                    actions: [],
                    elapsedSeconds: elapsed
                )
            } catch {
                // Any FM error -> fall back so the overlay still answers.
                return try await fallback.ask(query: query, context: context)
            }
        }
        #endif

        return try await fallback.ask(query: query, context: context)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func makeSession() -> LanguageModelSession {
        LanguageModelSession(
            tools: [
                FoundationFindEventsTool(tool: registry.findEvents, clock: clock),
                FoundationFindFreeSlotsTool(tool: registry.findFreeSlots, clock: clock),
                FoundationScanInboxTool(tool: registry.scanInbox, clock: clock),
                FoundationSummarizeWeekTool(tool: registry.summarizeWeek, clock: clock),
                FoundationLastInteractionTool(tool: registry.lastInteraction, clock: clock),
            ],
            instructions: SystemPrompt.default
        )
    }

    /// Two-phase citation resolution:
    /// 1. Walk the session transcript and extract any event ids that the
    ///    `findEvents` tool returned during this turn. These are
    ///    authoritative — the model literally pulled them from the store.
    /// 2. If no tool ran (model answered from instructions alone), fall
    ///    back to the substring-heuristic citation resolver on the body.
    @available(iOS 26.0, *)
    private func resolveCitations(
        session: LanguageModelSession,
        body: String
    ) async -> [AICitation] {
        let toolEventIDs = extractFindEventsIDs(transcript: session.transcript)
        if !toolEventIDs.isEmpty {
            return await citations(forIDs: toolEventIDs)
        }
        return await fallback.resolveCitations(forBody: body, now: clock())
    }

    /// Scan the transcript for entries that came from the `findEvents`
    /// tool and parse out the event ids it returned. We're tolerant of
    /// shape changes in the framework: each transcript entry is converted
    /// to a `String` description and a regex pulls out UUID-shaped tokens
    /// from any block tagged with the tool name.
    @available(iOS 26.0, *)
    private func extractFindEventsIDs(transcript: Transcript) -> [UUID] {
        let blob = transcript
            .map { "\($0)" }
            .joined(separator: "\n")
        // Quick reject: no tool output means no ids to pull.
        guard blob.contains("findEvents") else { return [] }

        let pattern = #"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(blob.startIndex ..< blob.endIndex, in: blob)
        var seen = Set<UUID>()
        var ordered: [UUID] = []
        regex.enumerateMatches(in: blob, range: range) { match, _, _ in
            guard let match,
                  let swiftRange = Range(match.range, in: blob),
                  let uuid = UUID(uuidString: String(blob[swiftRange])),
                  !seen.contains(uuid) else { return }
            seen.insert(uuid)
            ordered.append(uuid)
        }
        return Array(ordered.prefix(3))
    }

    /// Build `AICitation`s for a known list of event ids by re-fetching
    /// the events through the registry's `FindEventsTool`. Uses a wide
    /// ±4-week query window so even out-of-view events resolve.
    @available(iOS 26.0, *)
    private func citations(forIDs ids: [UUID]) async -> [AICitation] {
        let now = clock()
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .day, value: -28, to: now) ?? now
        let end = calendar.date(byAdding: .day, value: 28, to: now) ?? now
        let allInWindow = (try? await registry.findEvents.run(query: EventQuery(
            dateRange: start ... end,
            categories: nil,
            keywords: [],
            personName: nil
        ))) ?? []
        let byID = Dictionary(uniqueKeysWithValues: allInWindow.map { ($0.id, $0) })

        return ids.compactMap { id -> AICitation? in
            guard let event = byID[id],
                  let category = Category(rawValue: event.categoryRaw) else { return nil }
            return AICitation(
                id: event.id,
                title: event.title,
                category: category,
                weekdayLong: Self.weekdayFormatter.string(from: event.start),
                timeShort: Self.timeFormatter.string(from: event.start)
            )
        }
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
    #endif
}
