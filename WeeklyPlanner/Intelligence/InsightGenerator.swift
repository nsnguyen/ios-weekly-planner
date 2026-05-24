import Foundation

/// Kinds of AI sticky-note insights that can render on a Day page.
/// Cascade priority ascends (0 = earliest in the stack); each kind has
/// a deterministic sticky-paper color from the existing palette.
enum InsightKind: String, CaseIterable, Codable, Sendable {
    /// `.encouragement` — fallback one-line nudge when none of the
    /// other generators produce a result. Listed first so it heads
    /// `allCases` (matches the orchestrator's fallback-first iteration).
    case encouragement
    /// `.travel` — "Leave by HH:mm for <event>" (MapKit ETA)
    case travel
    /// `.weather` — "Bring umbrella — rain at <h>pm" (WeatherKit)
    case weather
    /// `.keyword` — "Don't forget Sara's gift!" (Foundation Models)
    case keyword
    /// `.inbox` — "<n> inbox suggestions for today"
    case inbox

    /// Cascade sort order. Lower = top of the stack. `9` is the
    /// fallback floor used by encouragement.
    var defaultPriority: Int {
        switch self {
        case .travel: return 0
        case .weather: return 1
        case .keyword: return 2
        case .inbox: return 3
        case .encouragement: return 9
        }
    }

    /// Sticky paper color hex matching the existing palette in
    /// `EncouragementInsightGenerator.palette`. Centralised here so the
    /// orchestrator picks the right color per kind without each
    /// generator hard-coding it.
    var colorHex: String {
        switch self {
        case .travel: return "#FFE680"        // yellow
        case .weather: return "#C9F0E0"       // mint
        case .keyword: return "#FFCCC9"       // pink
        case .inbox: return "#E0DFFF"         // lavender (new)
        case .encouragement: return "#FFE680" // yellow (legacy default)
        }
    }
}

/// Snapshot of everything an `InsightGenerator` needs to decide whether
/// to emit an insight for a given day. Pure value type — `Sendable` so
/// it can cross task boundaries inside the orchestrator's task group.
///
/// `Event` and `InboxSuggestion` are SwiftData `@Model` classes (NOT
/// `Sendable`), so we pass them as `[Event]` / `[InboxSuggestion]` only
/// when the orchestrator can guarantee the captures stay on `@MainActor`
/// — the generators that need them are `@MainActor`-isolated. Marked
/// `@unchecked Sendable` to honor that contract: every consumer
/// (`StickyOrchestrator`, every generator) is `@MainActor`-bound, so
/// the contained `@Model` arrays never actually leave the MainActor
/// even when the value type itself nominally crosses an actor hop in
/// a child task that immediately re-enters the MainActor.
struct DayContext: @unchecked Sendable {
    let weekOffset: Int
    let dayIdx: Int
    let events: [Event]
    let inbox: [InboxSuggestion]
    let now: Date
    let appleIntelligenceEnabled: Bool

    /// Convenience over `AIInsight.key(weekOffset:dayIdx:)` so generators
    /// don't repeat the encoding.
    var dayKey: String { AIInsight.key(weekOffset: weekOffset, dayIdx: dayIdx) }
}

/// One signal source for the AI sticky-note cascade. Every generator
/// returns at most one `AIInsight` per call — the orchestrator runs
/// all five generators in parallel and assembles the cascade.
///
/// Refined to `Sendable` so existentials (`any InsightGenerator`) can
/// be captured by the orchestrator's `withTaskGroup` child tasks under
/// Swift 6 strict concurrency. Safe because the protocol is
/// `@MainActor`-isolated end-to-end — generators only execute on the
/// MainActor regardless of where the existential travels.
@MainActor
protocol InsightGenerator: Sendable {
    /// What kind of insight this generator produces. Used by the
    /// orchestrator to enforce `(dayKey, kind)` uniqueness at persist
    /// time and to dispatch the right color / priority.
    var kind: InsightKind { get }

    /// Emit an insight, or `nil` if this generator has nothing to say
    /// for this day. Implementations must `do/catch` any thrown errors
    /// internally and convert them to `nil` — the orchestrator cannot
    /// recover from per-generator failures.
    func generate(for day: DayContext) async -> AIInsight?
}
