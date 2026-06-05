import Foundation
import SwiftData

/// Kind flag for a note: a loose miscellaneous note or a standing goal.
/// Stored as a raw String (SwiftData-predicate friendly) and mirrored by
/// the typed accessor below — same pattern as `TaskItem.priority`.
enum NoteKind: String, CaseIterable, Codable, Sendable {
    case misc
    case goal
}

/// Free-form note on the Notes tab (Phase 33). Not tied to a day —
/// `dayKey` is reserved for a future "note for a specific day" link and
/// is always `nil` for now.
@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var kindRaw: String
    /// Reserved: `"<weekOffset>:<dayIdx>"` if a note is ever pinned to a day.
    var dayKey: String?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         title: String,
         body: String,
         kind: NoteKind = .misc,
         dayKey: String? = nil,
         createdAt: Date = .init(),
         updatedAt: Date = .init())
    {
        self.id = id
        self.title = title
        self.body = body
        kindRaw = kind.rawValue
        self.dayKey = dayKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Note {
    var kind: NoteKind {
        get { NoteKind(rawValue: kindRaw) ?? .misc }
        set { kindRaw = newValue.rawValue }
    }
}
