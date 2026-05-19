import Foundation

@MainActor
final class LastInteractionTool: PlannerTool {
    let name = "lastInteraction"
    private let store: any EventStoring

    init(store: any EventStoring) {
        self.store = store
    }

    /// Returns the most recent event whose title or location case-insensitively
    /// contains `personName`, scanning the eight weeks ending at `today`.
    func run(personName: String, today: Date) async throws -> ToolLastInteraction {
        let lowered = personName.lowercased()
        guard !lowered.isEmpty else {
            return ToolLastInteraction(eventID: nil, date: nil, context: "")
        }
        var best: Event?
        for weekOffset in -8 ... 0 {
            let events = (try? await store.events(forWeekOffset: weekOffset, today: today)) ?? []
            for event in events where event.start <= today {
                let title = event.title.lowercased()
                let location = (event.location ?? "").lowercased()
                guard title.contains(lowered) || location.contains(lowered) else { continue }
                if best == nil || event.start > best!.start {
                    best = event
                }
            }
        }
        guard let match = best else {
            return ToolLastInteraction(eventID: nil, date: nil, context: "")
        }
        return ToolLastInteraction(eventID: match.id, date: match.start, context: match.title)
    }
}
