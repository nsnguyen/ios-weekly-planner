import Foundation
import SwiftData

/// CRUD surface for Notes-tab notes. Mirrors `TaskStoring`.
@MainActor
protocol NoteStoring: AnyObject {
    /// All notes, most-recently-updated first.
    func notes() async throws -> [Note]
    func note(id: UUID) async throws -> Note?
    func upsert(_ note: Note) async throws
    func delete(id: UUID) async throws
}

@MainActor
final class SwiftDataNoteStore: NoteStoring {
    private let context: ModelContext
    private let changeSubject = NotificationCenter.default

    init(context: ModelContext) {
        self.context = context
    }

    func notes() async throws -> [Note] {
        try context.fetch(FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\Note.updatedAt, order: .reverse)]))
    }

    func note(id: UUID) async throws -> Note? {
        try context.fetch(FetchDescriptor<Note>(predicate: #Predicate<Note> { $0.id == id })).first
    }

    func upsert(_ note: Note) async throws {
        let id = note.id
        let existing = try context.fetch(FetchDescriptor<Note>(predicate: #Predicate<Note> { $0.id == id })).first

        if let existing {
            existing.title = note.title
            existing.body = note.body
            existing.kindRaw = note.kindRaw
            existing.dayKey = note.dayKey
            existing.updatedAt = .init()
        } else {
            context.insert(note)
        }
        try context.save()
        changeSubject.post(name: .noteStoreDidChange, object: nil)
    }

    func delete(id: UUID) async throws {
        guard let note = try await note(id: id) else { return }
        context.delete(note)
        try context.save()
        changeSubject.post(name: .noteStoreDidChange, object: nil)
    }
}

extension Notification.Name {
    static let noteStoreDidChange = Notification.Name("WeeklyPlanner.NoteStore.didChange")
}
