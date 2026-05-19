import Foundation

/// Tool exposed to the language model: "find events that match this
/// query". Returns compact `ToolEventResult`s so the model never sees a
/// SwiftData entity. Swallows store errors and returns `[]` so a flaky
/// fetch can't crash the model run loop.
@MainActor
final class FindEventsTool: PlannerTool {
    let name = "findEvents"
    private let store: any EventStoring

    init(store: any EventStoring) {
        self.store = store
    }

    func run(query: EventQuery) async throws -> [ToolEventResult] {
        let events = (try? await store.events(matching: query)) ?? []
        return events.map { event in
            ToolEventResult(
                id: event.id,
                title: event.title,
                start: event.start,
                end: event.end,
                location: event.location,
                categoryRaw: event.categoryRaw,
                sourceRaw: event.sourceRaw
            )
        }
    }
}
