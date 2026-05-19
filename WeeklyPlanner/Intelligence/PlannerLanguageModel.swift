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
    private let clock: () -> Date

    init(registry: ToolRegistry,
         fallback: StubIntelligenceService,
         clock: @escaping () -> Date = { Date() })
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
                let citations = await fallback.resolveCitations(forBody: body, now: clock())
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
        // Foundation Models adopters typically pass `Tool` conformers here.
        // Phase 13-b will adapt each `PlannerTool` into a `Tool` once the
        // generation-schema work lands; v1.0 ships instructions-only and
        // leans on the system prompt to keep answers grounded.
        return LanguageModelSession(instructions: SystemPrompt.default)
    }
    #endif
}
