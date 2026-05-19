import Foundation

/// Produces a `WeekSummary` for the Review page. Aggregates store data
/// (tasks done/total, hours-by-category) deterministically, then asks the
/// `IntelligenceService` for a handwritten one-paragraph headline plus
/// three star-bullet notes.
///
/// Falls back to `WeekSummary.fallback(...)` when the model is unavailable
/// so the Review page always renders with useful copy.
@MainActor
final class WeekSummaryGenerator {
    private let intelligence: any IntelligenceService
    private let events: any EventStoring
    private let tasks: any TaskStoring
    private let settings: () -> Bool

    init(intelligence: any IntelligenceService,
         events: any EventStoring,
         tasks: any TaskStoring,
         settings: @escaping () -> Bool = { true })
    {
        self.intelligence = intelligence
        self.events = events
        self.tasks = tasks
        self.settings = settings
    }

    func generate(weekOffset: Int, today: Date) async throws -> WeekSummary {
        let weekEvents = (try? await events.events(forWeekOffset: weekOffset, today: today)) ?? []
        let weekTasks = (try? await tasks.tasks(forWeekOffset: weekOffset, today: today)) ?? []

        var hoursByCategory: [String: Double] = [:]
        for event in weekEvents {
            let hours = event.end.timeIntervalSince(event.start) / 3600.0
            hoursByCategory[event.categoryRaw, default: 0] += hours
        }
        let tasksDone = weekTasks.filter(\.done).count
        let tasksTotal = weekTasks.count
        let pct = tasksTotal == 0 ? 0.0 : Double(tasksDone) / Double(tasksTotal)

        let context = PlannerContext(
            now: today,
            viewedWeekOffset: weekOffset,
            maxResponseTokens: 256,
            appleIntelligenceEnabled: settings()
        )
        let availability = await intelligence.availability(context: context)
        guard availability.isAvailable else {
            return WeekSummary.fallback(weekOffset: weekOffset,
                                         tasksDone: tasksDone,
                                         tasksTotal: tasksTotal)
        }

        let prompt = Self.prompt(weekOffset: weekOffset,
                                 tasksDone: tasksDone,
                                 tasksTotal: tasksTotal,
                                 hoursByCategory: hoursByCategory)
        do {
            let answer = try await intelligence.ask(query: prompt, context: context)
            let trimmed = answer.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return WeekSummary.fallback(weekOffset: weekOffset,
                                             tasksDone: tasksDone,
                                             tasksTotal: tasksTotal)
            }
            // Phase 14 ships with model output as a single headline string.
            // Bullet structuring (per-line ink) is a Phase 14-b polish item;
            // for now we keep the canned bullets as design placeholders
            // alongside the live headline so the visual rhythm holds.
            let fallback = WeekSummary.fallback(weekOffset: weekOffset,
                                                  tasksDone: tasksDone,
                                                  tasksTotal: tasksTotal)
            return WeekSummary(headline: trimmed,
                                bullets: fallback.bullets,
                                completionPercent: pct)
        } catch {
            return WeekSummary.fallback(weekOffset: weekOffset,
                                         tasksDone: tasksDone,
                                         tasksTotal: tasksTotal)
        }
    }

    /// Pure prompt builder. Exposed for tests so the format stays stable.
    static func prompt(weekOffset: Int,
                       tasksDone: Int,
                       tasksTotal: Int,
                       hoursByCategory: [String: Double]) -> String
    {
        let hoursLines = hoursByCategory
            .sorted { $0.key < $1.key }
            .map { "- \($0.key): \(String(format: "%.1f", $0.value))h" }
            .joined(separator: "\n")
        return """
        Write a warm, handwritten-style one-paragraph reflection on the user's week (≤ 2 sentences, plain text only, no markdown or quotes).

        Week offset: \(weekOffset)
        Tasks: \(tasksDone) of \(tasksTotal) done
        Hours by category:
        \(hoursLines)

        Reply with just the paragraph — no preamble.
        """
    }
}
