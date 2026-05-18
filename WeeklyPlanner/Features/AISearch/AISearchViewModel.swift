import Foundation
import Observation

/// Drives the Paper AI Search overlay. Owns the query string, the
/// "thinking" indicator state, and the most recent rendered `AIAnswer`.
///
/// In Phase 12 the answer pipeline is fully stubbed — `ask(text:)` looks up
/// a handwritten reply in `AISearchCannedData` and resolves any citation
/// events from the live `EventStore` by title-substring match. Phase 13
/// swaps the body of `ask(text:)` for an `IntelligenceService` call against
/// Foundation Models; everything else (citation resolver, thinking flag,
/// elapsed-time footer) stays.
///
/// `@MainActor`-isolated because all store calls are `@MainActor`-bound and
/// SwiftUI views read `@Observable` properties from the main run loop.
@MainActor
@Observable
final class AISearchViewModel {
    /// Current text in the ask input. Mutated by the view's `TextField`
    /// binding and updated by `ask(text:)` when a suggestion fires.
    var query: String = ""

    /// `true` while the artificial "model is inferring" delay is running.
    /// Drives the ink-shimmer "thinking" indicator (State B).
    var thinking: Bool = false

    /// Latest rendered answer, or `nil` while in State A (no answer yet) or
    /// State B (mid-think). Set atomically at the end of `ask(text:)`.
    var answer: AIAnswer?

    /// Artificial delay simulating model inference latency. Phase 13
    /// replaces this with actual `Foundation Models` call timing. Exposed
    /// `var` so tests can collapse it to zero.
    var thinkingDelay: Duration = .milliseconds(1100)

    private let eventStore: any EventStoring
    private let clock: () -> Date

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - eventStore: Store used to resolve citation events by title.
    ///   - clock: Injected "now" so tests can pin the date. Defaults to
    ///     `Date()` in production.
    init(eventStore: any EventStoring, clock: @escaping () -> Date = { Date() }) {
        self.eventStore = eventStore
        self.clock = clock
    }

    /// Convenience entry point for the suggestion list: forwards to
    /// `ask(text:)` with the suggestion's display text.
    func ask(_ suggestion: AISuggestion) async {
        await ask(text: suggestion.text)
    }

    /// Fire a query end-to-end: flip into thinking state, wait
    /// `thinkingDelay`, then publish the canned answer along with any
    /// citation events resolved from the live store.
    func ask(text: String) async {
        query = text
        thinking = true
        answer = nil

        let started = Date()
        try? await Task.sleep(for: thinkingDelay)

        let stub = AISearchCannedData.canned(for: text)
        let citations = await resolveCitations(titleHints: stub.titleHints)
        let elapsed = Date().timeIntervalSince(started)
        answer = AIAnswer(query: text,
                          body: stub.body,
                          citations: citations,
                          actions: stub.actions,
                          elapsedSeconds: elapsed)
        thinking = false
    }

    /// Reset the view model to State A (no query, no answer, not thinking).
    /// Called by the overlay's "Close" button.
    func clear() {
        query = ""
        thinking = false
        answer = nil
    }

    /// Fetches events whose titles contain any of the `titleHints`
    /// substrings (case-insensitive) and surfaces them as `AICitation`s.
    /// Scans ±4 weeks around `clock()` and stops at the first 3 hits, in the
    /// order they're encountered.
    private func resolveCitations(titleHints: [String]) async -> [AICitation] {
        guard !titleHints.isEmpty else { return [] }
        let lowercasedHints = titleHints.map { $0.lowercased() }
        var results: [AICitation] = []
        for weekOffset in -4 ... 4 {
            guard let events = try? await eventStore.events(forWeekOffset: weekOffset, today: clock()) else {
                continue
            }
            for event in events {
                let titleLower = event.title.lowercased()
                guard lowercasedHints.contains(where: { titleLower.contains($0) }) else { continue }
                results.append(AICitation(id: event.id,
                                          title: event.title,
                                          category: event.category,
                                          weekdayLong: Self.weekdayFormatter.string(from: event.start),
                                          timeShort: Self.timeFormatter.string(from: event.start)))
                if results.count >= 3 { return results }
            }
        }
        return results
    }

    /// `"Saturday"`-style long weekday formatter, pinned to POSIX locale so
    /// the test suite is deterministic across environments.
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// `"8 PM"`-style short time formatter, POSIX-locked.
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
