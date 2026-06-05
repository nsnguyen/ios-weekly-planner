import Foundation
import Observation

/// Drives the Notes tab. Loads through `NoteStoring` so tests/previews
/// inject `SwiftDataNoteStore` (in-memory) / `StubNoteStore`.
@MainActor
@Observable
final class NotesViewModel {
    private let store: any NoteStoring

    var notes: [Note] = []
    var loadError: String?

    init(store: any NoteStoring) {
        self.store = store
    }

    func load() async {
        do {
            notes = try await store.notes()
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Persists a new note. Returns `nil` (and persists nothing) when both
    /// trimmed title and body are empty — an abandoned editor draft.
    @discardableResult
    func create(title: String, body: String, kind: NoteKind) async -> Note? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !(trimmedTitle.isEmpty && trimmedBody.isEmpty) else { return nil }

        let note = Note(title: trimmedTitle, body: trimmedBody, kind: kind)
        do {
            try await store.upsert(note)
            await load()
            return note
        } catch {
            loadError = error.localizedDescription
            return nil
        }
    }

    func update(id: UUID, title: String, body: String, kind: NoteKind) async {
        do {
            guard let existing = try await store.note(id: id) else { return }
            existing.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.kind = kind
            try await store.upsert(existing)
            await load()
        } catch {
            loadError = error.localizedDescription
        }
    }

    func delete(id: UUID) async {
        do {
            try await store.delete(id: id)
            await load()
        } catch {
            loadError = error.localizedDescription
        }
    }
}
