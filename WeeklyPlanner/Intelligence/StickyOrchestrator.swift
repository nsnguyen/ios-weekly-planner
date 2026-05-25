import Foundation
import SwiftData

/// Runs Phase 24's five insight generators (travel / weather / keyword /
/// inbox primary + encouragement fallback) and assembles the AI sticky
/// cascade for a day. Persists results into SwiftData as `AIInsight`
/// rows, enforcing logical `(dayKey, kind)` uniqueness by deleting
/// existing non-dismissed rows for the same kind before inserting fresh
/// ones.
///
/// Caches results per `(dayKey, eventsHash)` for `cacheTTL` seconds so
/// rapid page-flips don't re-hit the network / Foundation Models.
@MainActor
final class StickyOrchestrator {
    private let generators: [any InsightGenerator]
    private let fallback: any InsightGenerator
    private let cacheTTL: TimeInterval

    /// Per-(dayKey,eventsHash) cache. Value is the timestamp of the
    /// last successful run. The cache *just records that a run
    /// happened* — the actual insights are read from SwiftData by the
    /// view model — so the cache value type is `Date`, not the
    /// insights themselves.
    private var cache: [String: Date] = [:]

    /// Cap on how many insights the orchestrator persists per day.
    static let cascadeCap = 3

    init(generators: [any InsightGenerator],
         fallback: any InsightGenerator,
         cacheTTL: TimeInterval = 5 * 60)
    {
        self.generators = generators
        self.fallback = fallback
        self.cacheTTL = cacheTTL
    }

    /// Run the cascade for `day` and persist results into `context`.
    /// Idempotent: calling repeatedly within `cacheTTL` is a no-op
    /// (returns immediately). Call `invalidate(_:)` to bypass.
    func run(for day: DayContext, into context: ModelContext) async {
        let key = cacheKey(for: day)
        if let stamp = cache[key],
           day.now.timeIntervalSince(stamp) < cacheTTL
        {
            return
        }

        // Track dismissed-text per kind so we don't re-emit something
        // the user already kicked off the page.
        let dismissedText = dismissedTextByKind(dayKey: day.dayKey, in: context)

        // Run primaries concurrently. Each generator handles its own
        // errors and returns nil on failure.
        //
        // `AIInsight` is `@Model` and therefore NOT `Sendable`, so we
        // cannot send it through a `TaskGroup`'s buffered channel under
        // Swift 6 strict concurrency. Instead, each task returns a
        // `Sendable` `InsightDraft` (a value-type snapshot of every
        // field the orchestrator needs) and we reconstruct the
        // `AIInsight` rows on the MainActor *after* the group finishes.
        var drafts: [InsightDraft] = []
        await withTaskGroup(of: InsightDraft?.self) { group in
            for gen in generators {
                group.addTask {
                    await Self.generateDraft(gen: gen, day: day)
                }
            }
            for await draft in group {
                if let draft {
                    let dismissed = dismissedText[draft.kind] ?? []
                    if dismissed.contains(draft.text) { continue }
                    drafts.append(draft)
                }
            }
        }

        // Sort by priority, cap at the cascade limit.
        drafts.sort { $0.priority < $1.priority }
        let cappedDrafts = Array(drafts.prefix(Self.cascadeCap))

        var toPersist: [AIInsight] = cappedDrafts.map { $0.makeInsight() }
        if toPersist.isEmpty {
            if let fb = await fallback.generate(for: day) {
                toPersist = [fb]
            }
        }

        persist(toPersist, day: day, into: context)
        cache[key] = day.now
    }

    /// Hop a child task back onto the MainActor to invoke the generator
    /// and convert the resulting `AIInsight` into a `Sendable`
    /// `InsightDraft`. Hoisted out of `run(for:into:)` because Swift 6's
    /// region-based isolation checker can't currently prove safety when
    /// `@MainActor in` is applied directly to a `group.addTask {}`
    /// closure that captures non-Sendable existentials — moving the
    /// MainActor hop into a separate `@MainActor` static func sidesteps
    /// the analyzer limitation while preserving the exact same runtime
    /// behavior (every generator runs on the MainActor).
    @MainActor
    private static func generateDraft(gen: any InsightGenerator,
                                       day: DayContext) async -> InsightDraft? {
        guard let insight = await gen.generate(for: day) else { return nil }
        return InsightDraft(insight: insight)
    }

    /// Force the next `run(for:)` call for this day to skip the cache.
    /// Wired to the day-page "↻" refresh button and to pull-to-refresh.
    func invalidate(dayKey: String) {
        cache = cache.filter { !$0.key.hasPrefix("\(dayKey):") }
    }

    // MARK: - Persistence

    /// Deletes existing non-dismissed rows for the same `(dayKey, kind)`
    /// pairs covered by `insights`, then inserts the new ones. Saves
    /// once at the end.
    private func persist(_ insights: [AIInsight],
                          day: DayContext,
                          into context: ModelContext)
    {
        let dayKey = day.dayKey
        let kindsToReplace = Set(insights.map { $0.kindRaw })
        let descriptor = FetchDescriptor<AIInsight>(
            predicate: #Predicate { $0.dayKey == dayKey && !$0.dismissed })
        if let existing = try? context.fetch(descriptor) {
            for row in existing where kindsToReplace.contains(row.kindRaw) {
                context.delete(row)
            }
        }
        for insight in insights {
            context.insert(insight)
        }
        try? context.save()
    }

    /// Build a map of dismissed insight texts per kind, used to skip
    /// re-emitting something the user already dismissed (so they don't
    /// see "Don't forget Sara's gift!" pop back five seconds later).
    private func dismissedTextByKind(dayKey: String, in context: ModelContext) -> [InsightKind: Set<String>] {
        let descriptor = FetchDescriptor<AIInsight>(
            predicate: #Predicate { $0.dayKey == dayKey && $0.dismissed })
        guard let dismissed = try? context.fetch(descriptor) else { return [:] }
        var byKind: [InsightKind: Set<String>] = [:]
        for row in dismissed {
            byKind[row.kind, default: []].insert(row.text)
        }
        return byKind
    }

    private func cacheKey(for day: DayContext) -> String {
        let eventsHash = day.events
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString):\(Int($0.start.timeIntervalSince1970))" }
            .joined(separator: ",")
            .hashValue
        return "\(day.dayKey):\(eventsHash)"
    }
}

/// Value-type `Sendable` snapshot of every field the orchestrator needs
/// from a freshly-built `AIInsight`. Generators run inside a task group
/// and must hand their results back through the group's buffered
/// channel, which requires `Sendable`. `AIInsight` is `@Model` (and
/// therefore `@MainActor`-bound, not `Sendable`), so we travel as a
/// draft and reconstruct the model row on the MainActor consumer side
/// via `makeInsight()`.
private struct InsightDraft: Sendable {
    let dayKey: String
    let text: String
    let colorHex: String
    let tiltDegrees: Double
    let dismissed: Bool
    let kind: InsightKind
    let actionURL: String?
    let priority: Int

    @MainActor
    init(insight: AIInsight) {
        self.dayKey = insight.dayKey
        self.text = insight.text
        self.colorHex = insight.colorHex
        self.tiltDegrees = insight.tiltDegrees
        self.dismissed = insight.dismissed
        self.kind = insight.kind
        self.actionURL = insight.actionURL
        self.priority = insight.priority
    }

    @MainActor
    func makeInsight() -> AIInsight {
        AIInsight(dayKey: dayKey,
                  text: text,
                  colorHex: colorHex,
                  tiltDegrees: tiltDegrees,
                  dismissed: dismissed,
                  kind: kind,
                  actionURL: actionURL,
                  priority: priority)
    }
}
