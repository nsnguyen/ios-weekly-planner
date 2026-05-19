import Foundation

/// One chunk of a streamed reply. Phase 13-a emits a single delta with the
/// full body; Phase 13-b layers tokenized streaming on top once the
/// FoundationModels API surface is exercised on-device.
struct AnswerDelta: Equatable, Sendable {
    let textChunk: String
    /// When `true`, the model has finished producing tokens and the
    /// citations / actions on the parent `AIAnswer` are final.
    let isFinal: Bool
}

/// The only surface the AI overlay, sticky generator, and review summary
/// generator talk to. Concrete conformers: `PlannerLanguageModel` (real
/// Foundation Models) and `StubIntelligenceService` (deterministic,
/// reused as the runtime fallback when the model is unavailable).
@MainActor
protocol IntelligenceService: AnyObject {
    /// Probe the on-device model + settings. Cheap; called at the start of
    /// every `ask(...)` so a Settings flip takes effect immediately.
    func availability(context: PlannerContext) async -> AvailabilityState

    /// Synchronous request/response — what the AI overlay calls today.
    func ask(query: String, context: PlannerContext) async throws -> AIAnswer

    /// Streamed request/response — Phase 13-b will swap the overlay to
    /// this. The default conformance in this phase emits a single final
    /// delta carrying the body of `ask(...)`.
    func streamAsk(query: String, context: PlannerContext)
        -> AsyncThrowingStream<AnswerDelta, Error>
}

extension IntelligenceService {
    /// Default streaming implementation: call `ask(...)` once, emit a
    /// single final delta. Concrete conformers override when they support
    /// real token streaming.
    func streamAsk(query: String, context: PlannerContext)
        -> AsyncThrowingStream<AnswerDelta, Error>
    {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    let answer = try await ask(query: query, context: context)
                    continuation.yield(AnswerDelta(textChunk: answer.body, isFinal: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
