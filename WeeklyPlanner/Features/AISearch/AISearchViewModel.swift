import Foundation
import Observation

/// Drives the Paper AI Search overlay. Owns the query string, the
/// "thinking" indicator state, and the most recent rendered `AIAnswer`.
///
/// Phase 13 wires this through an `IntelligenceService`. If the service
/// reports unavailable (user disabled AI in Settings, model not ready,
/// device ineligible), the view model still publishes an answer — from
/// the same `StubIntelligenceService` used in tests — and exposes
/// `unavailableReason` so the view layer can render the fallback footer.
@MainActor
@Observable
final class AISearchViewModel {
    /// Current text in the ask input. Mutated by the view's `TextField`
    /// binding and updated by `ask(text:)` when a suggestion fires.
    var query: String = ""

    /// `true` while a request is in flight. Drives the ink-shimmer
    /// "thinking" indicator (State B).
    var thinking: Bool = false

    /// Latest rendered answer, or `nil` while in State A (no answer yet)
    /// or State B (mid-think). Set atomically at the end of `ask(text:)`.
    var answer: AIAnswer?

    /// Set after every `ask(...)`. `.available` for the happy path; the
    /// view layer renders the `.fallbackMessage` whenever the case is
    /// `.unavailable(...)`.
    var unavailableReason: AvailabilityState = .available

    /// Only used by the canned fallback path so existing snapshot timing
    /// stays stable. The live FM path uses real latency and ignores this.
    var thinkingDelay: Duration = .milliseconds(1100)

    private let eventStore: any EventStoring
    private let intelligence: any IntelligenceService
    private let settings: () -> Bool
    private let clock: () -> Date

    init(eventStore: any EventStoring,
         intelligence: any IntelligenceService,
         settings: @escaping () -> Bool = { true },
         clock: @escaping () -> Date = { Date() })
    {
        self.eventStore = eventStore
        self.intelligence = intelligence
        self.settings = settings
        self.clock = clock
    }

    /// Convenience entry point for the suggestion list: forwards to
    /// `ask(text:)` with the suggestion's display text.
    func ask(_ suggestion: AISuggestion) async {
        await ask(text: suggestion.text)
    }

    /// Fire a query end-to-end: flip into thinking state, call the
    /// intelligence service (or the fallback if it's unavailable), then
    /// publish the resolved answer.
    func ask(text: String) async {
        query = text
        thinking = true
        answer = nil

        let context = PlannerContext(
            now: clock(),
            viewedWeekOffset: 0,
            maxResponseTokens: 256,
            appleIntelligenceEnabled: settings()
        )
        let availability = await intelligence.availability(context: context)
        unavailableReason = availability

        let started = Date()
        if !availability.isAvailable {
            // Match prior Phase 12 timing so the overlay UX doesn't snap.
            try? await Task.sleep(for: thinkingDelay)
        }
        do {
            let produced = try await intelligence.ask(query: text, context: context)
            let elapsed = Date().timeIntervalSince(started)
            answer = AIAnswer(
                query: produced.query,
                body: produced.body,
                citations: produced.citations,
                actions: produced.actions,
                elapsedSeconds: elapsed
            )
        } catch {
            // Last-ditch fallback — produce a short message rather than
            // leaving the overlay stuck in "thinking" forever.
            answer = AIAnswer(
                query: text,
                body: "Something went wrong. Try again in a moment.",
                citations: [],
                actions: [],
                elapsedSeconds: Date().timeIntervalSince(started)
            )
        }
        thinking = false
    }

    /// Reset the view model to State A (no query, no answer, not thinking).
    /// Called by the overlay's "Close" button.
    func clear() {
        query = ""
        thinking = false
        answer = nil
        unavailableReason = .available
    }
}
