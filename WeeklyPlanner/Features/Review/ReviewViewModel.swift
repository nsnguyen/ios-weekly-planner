import Foundation
import Observation

/// Drives the Paper Review page. Aggregates per-week stats from the
/// existing stores and exposes a three-state `SummaryState` that the AI
/// summary + notes blocks read. Phase 32 (#38): no state fabricates
/// content — no canned summaries, no hardcoded streaks.
@MainActor
@Observable
final class ReviewViewModel {
    /// What the AI summary area should render. Three honest states —
    /// real model output, an "AI off" invitation, or nothing at all.
    enum SummaryState: Equatable {
        /// Real on-device model output — render it.
        case real(WeekSummary)
        /// AI is off/unavailable — render the one-line enable prompt.
        case aiOff
        /// AI is on but there's nothing to show (genuinely empty week,
        /// model failure) — omit the block entirely.
        case hidden
    }

    let weekOffset: Int

    /// Hours-by-category for the week, sorted descending elsewhere by
    /// the view layer.
    var timeByCategory: [Category: Double] = [:]

    /// Largest single per-category hour count. Drives the bar-chart's
    /// proportional fills. Defaults to 1 so an empty week renders without
    /// a divide-by-zero in the bar fill calculation.
    var maxHours: Double = 1.0

    var tasksDone: Int = 0
    var tasksTotal: Int = 0

    /// `0.0–1.0` share of the week's tasks completed.
    var completionPercent: Double = 0.0

    /// What the AI summary area renders. Starts `.hidden` so nothing
    /// flashes while the first `refresh()` is in flight.
    var summaryState: SummaryState = .hidden

    /// Always empty until a real `StreakStore` ships (later phase). The
    /// Streaks section hides itself when this is empty — no fabricated rows.
    var streaks: [Streak] = []

    /// Localized description of the most recent fetch failure, if any.
    var loadError: String?

    private let eventStore: any EventStoring
    private let taskStore: any TaskStoring
    private let summaryGenerator: WeekSummaryGenerator?
    private let clock: () -> Date

    init(weekOffset: Int,
         eventStore: any EventStoring,
         taskStore: any TaskStoring,
         summaryGenerator: WeekSummaryGenerator?,
         clock: @escaping () -> Date = { Date() })
    {
        self.weekOffset = weekOffset
        self.eventStore = eventStore
        self.taskStore = taskStore
        self.summaryGenerator = summaryGenerator
        self.clock = clock
    }

    /// Refresh aggregates + summary. Errors swallow into `loadError` so
    /// the page never crashes; the summary degrades honestly via
    /// `SummaryState` instead of falling back to canned copy.
    func refresh() async {
        let now = clock()

        do {
            let events = try await eventStore.events(forWeekOffset: weekOffset, today: now)
            var byCat: [Category: Double] = [:]
            for event in events {
                let hours = event.end.timeIntervalSince(event.start) / 3600.0
                let cat = Category(rawValue: event.categoryRaw) ?? .personal
                byCat[cat, default: 0] += hours
            }
            timeByCategory = byCat
            maxHours = max(1.0, byCat.values.max() ?? 1.0)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }

        do {
            let tasks = try await taskStore.tasks(forWeekOffset: weekOffset, today: now)
            tasksDone = tasks.filter(\.done).count
            tasksTotal = tasks.count
            completionPercent = tasksTotal == 0 ? 0.0 : Double(tasksDone) / Double(tasksTotal)
        } catch {
            loadError = error.localizedDescription
        }

        if let summaryGenerator {
            switch await summaryGenerator.generate(weekOffset: weekOffset, today: now) {
            case .generated(let produced): summaryState = .real(produced)
            case .unavailable: summaryState = .aiOff
            case .noContent: summaryState = .hidden
            }
        } else {
            // No intelligence service at all (older device, previews):
            // same honest treatment as the toggle being off.
            summaryState = .aiOff
        }
    }
}
