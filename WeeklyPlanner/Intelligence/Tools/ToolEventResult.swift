import Foundation

/// Wire-format event surfaced to the model. Plain values only — no
/// SwiftData entities cross the protocol boundary so the model layer can
/// be unit-tested without a live store.
struct ToolEventResult: Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let categoryRaw: String
    let sourceRaw: String
}

/// Compact free-slot pair returned by `FindFreeSlotsTool`.
struct ToolFreeSlot: Codable, Equatable, Sendable {
    let start: Date
    let end: Date
}

/// Compact inbox suggestion returned by `ScanInboxTool`.
struct ToolInboxResult: Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let proposedStart: Date
    let fromName: String?
    let subject: String?
}

/// Per-category hours rollup returned by `SummarizeWeekTool`.
struct ToolWeekSummary: Codable, Equatable, Sendable {
    let hoursByCategory: [String: Double]
    let tasksDone: Int
    let tasksOpen: Int
    let highlightEventIDs: [UUID]
}

/// Last-interaction record returned by `LastInteractionTool`.
struct ToolLastInteraction: Codable, Equatable, Sendable {
    let eventID: UUID?
    let date: Date?
    let context: String
}
