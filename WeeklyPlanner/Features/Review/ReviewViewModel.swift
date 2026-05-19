import Foundation
import Observation

/// Drives the Paper Review page. Aggregates per-week stats from the
/// existing stores and exposes the `WeekSummary` that the AI summary +
/// notes blocks read. Holds a hardcoded "Morning run" streak per spec
/// v1.0 — a later phase swaps that for a real `StreakStore`.
@MainActor
@Observable
final class ReviewViewModel {
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

    /// The AI (or fallback) week summary.
    var summary: WeekSummary

    /// Hardcoded for v1.0 — single "Morning run" streak.
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
        self.summary = WeekSummary.fallback(weekOffset: weekOffset,
                                             tasksDone: 0,
                                             tasksTotal: 0)
    }

    /// Refresh aggregates + summary. Errors swallow into `loadError` so
    /// the page never crashes; falls back to canned summary on any error.
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
            if let produced = try? await summaryGenerator.generate(weekOffset: weekOffset, today: now) {
                summary = produced
            } else {
                summary = WeekSummary.fallback(weekOffset: weekOffset,
                                                tasksDone: tasksDone,
                                                tasksTotal: tasksTotal)
            }
        } else {
            summary = WeekSummary.fallback(weekOffset: weekOffset,
                                            tasksDone: tasksDone,
                                            tasksTotal: tasksTotal)
        }

        streaks = [Self.morningRunStreak()]
    }

    /// Hardcoded "Morning run" streak per spec v1.0. A later phase
    /// introducing user-defined habits will replace this with a real
    /// `StreakStore` query.
    private static func morningRunStreak() -> Streak {
        Streak(name: "Morning run",
               emoji: "🏃",
               consecutiveWeeks: 6,
               last7Days: [true, false, true, false, true, false, true],
               categoryHint: .health)
    }
}
