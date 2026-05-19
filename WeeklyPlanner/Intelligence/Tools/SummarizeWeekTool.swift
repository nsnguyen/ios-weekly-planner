import Foundation

@MainActor
final class SummarizeWeekTool: PlannerTool {
    let name = "summarizeWeek"
    private let events: any EventStoring
    private let tasks: any TaskStoring

    init(events: any EventStoring, tasks: any TaskStoring) {
        self.events = events
        self.tasks = tasks
    }

    func run(weekOffset: Int, today: Date) async throws -> ToolWeekSummary {
        let weekEvents = (try? await events.events(forWeekOffset: weekOffset, today: today)) ?? []
        let weekTasks = (try? await tasks.tasks(forWeekOffset: weekOffset, today: today)) ?? []

        var hoursByCategory: [String: Double] = [:]
        for event in weekEvents {
            let hours = event.end.timeIntervalSince(event.start) / 3600.0
            hoursByCategory[event.categoryRaw, default: 0] += hours
        }
        let done = weekTasks.filter(\.done).count
        let open = weekTasks.count - done
        let highlights = weekEvents
            .sorted { lhs, rhs in
                lhs.end.timeIntervalSince(lhs.start) > rhs.end.timeIntervalSince(rhs.start)
            }
            .prefix(3)
            .map(\.id)

        return ToolWeekSummary(
            hoursByCategory: hoursByCategory,
            tasksDone: done,
            tasksOpen: open,
            highlightEventIDs: Array(highlights)
        )
    }
}
