import Foundation

/// Result of a week-summary generation attempt. Phase 32 (#38): the
/// generator no longer fabricates canned summaries — callers receive an
/// honest outcome and decide how to degrade.
enum WeekSummaryOutcome: Equatable, Sendable {
    /// The on-device model produced a real summary.
    case generated(WeekSummary)
    /// AI is off or unavailable (planner toggle, device eligibility,
    /// model state). Callers may invite the user to enable it.
    case unavailable
    /// AI is available but there is nothing to summarize (genuinely empty
    /// week), or the model returned no usable text.
    case noContent
}

/// Produces a `WeekSummary` for the Review page. Aggregates store data
/// (tasks done/total, hours-by-category) deterministically, then asks the
/// `IntelligenceService` for a handwritten one-paragraph headline.
///
/// Phase 32 (#38): never invents content. When the model is unavailable
/// the outcome is `.unavailable`; when the week is genuinely empty or the
/// model fails, the outcome is `.noContent`. The old canned
/// `WeekSummary.fallback` (fabricated streak/notes copy) is gone.
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

    func generate(weekOffset: Int, today: Date) async -> WeekSummaryOutcome {
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
        guard availability.isAvailable else { return .unavailable }

        // Genuinely empty week: nothing to summarize. Don't ask the model
        // to reflect on zero data — that's how fabricated content happens.
        guard !(weekEvents.isEmpty && weekTasks.isEmpty) else { return .noContent }

        let prompt = Self.prompt(weekOffset: weekOffset,
                                 tasksDone: tasksDone,
                                 tasksTotal: tasksTotal,
                                 hoursByCategory: hoursByCategory)
        do {
            let answer = try await intelligence.ask(query: prompt, context: context)
            let trimmed = answer.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return .noContent }
            // The model emits a single headline; bullet structuring is a
            // later polish item. Bullets stay empty — no design
            // placeholders alongside live output (Phase 32 #38).
            return .generated(WeekSummary(headline: trimmed,
                                          bullets: [],
                                          completionPercent: pct))
        } catch {
            return .noContent
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
