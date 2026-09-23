import Foundation

/// Stable, Foundation-Models-agnostic identifier for an Intelligence tool.
/// The same name is used in the system prompt, in tool dispatch, and as the
/// `Tool.name` exposed to `LanguageModelSession` once the FM bridge runs.
protocol PlannerTool: Sendable {
    var name: String { get }
}

/// Owns the five tools the Intelligence layer exposes to the model. Pure
/// protocol-talk to the stores so unit tests can swap in any
/// `EventStoring` / `TaskStoring` / `InboxStoring` conformer.
@MainActor
final class ToolRegistry {
    let findEvents: FindEventsTool
    let findFreeSlots: FindFreeSlotsTool
    let scanInbox: ScanInboxTool
    let summarizeWeek: SummarizeWeekTool
    let lastInteraction: LastInteractionTool

    init(events: any EventStoring, tasks: any TaskStoring, inbox: any InboxStoring) {
        findEvents = FindEventsTool(store: events)
        findFreeSlots = FindFreeSlotsTool(store: events)
        scanInbox = ScanInboxTool(store: inbox)
        summarizeWeek = SummarizeWeekTool(events: events, tasks: tasks)
        lastInteraction = LastInteractionTool(store: events)
    }

    /// Stable ordering — referenced by `SystemPrompt` to enumerate
    /// capabilities and by `ToolRegistryTests`.
    var allTools: [any PlannerTool] {
        [findEvents, findFreeSlots, scanInbox, summarizeWeek, lastInteraction]
    }
}
