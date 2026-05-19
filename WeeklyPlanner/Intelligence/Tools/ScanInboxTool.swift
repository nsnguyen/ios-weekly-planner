import Foundation

@MainActor
final class ScanInboxTool: PlannerTool {
    let name = "scanInbox"
    private let store: any InboxStoring

    init(store: any InboxStoring) {
        self.store = store
    }

    /// Returns up to `limit` pending suggestions for the given week offset.
    /// Quietly swallows store errors — an inbox tool failure shouldn't kill
    /// the whole model run.
    func run(weekOffset: Int, today: Date, limit: Int = 10) async throws -> [ToolInboxResult] {
        let raw = (try? await store.pending(forWeekOffset: weekOffset, today: today)) ?? []
        return raw.prefix(max(0, limit)).map { suggestion in
            ToolInboxResult(
                id: suggestion.id,
                title: suggestion.title,
                proposedStart: suggestion.proposedStart,
                fromName: suggestion.fromName,
                subject: suggestion.subject
            )
        }
    }
}
