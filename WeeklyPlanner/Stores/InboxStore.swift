import Foundation
import SwiftData

@MainActor
protocol InboxStoring: AnyObject {
    func pending(forWeekOffset offset: Int, today: Date) async throws -> [InboxSuggestion]
    func suggestion(id: UUID) async throws -> InboxSuggestion?
    func upsert(_ suggestion: InboxSuggestion) async throws
    func accept(id: UUID) async throws
    func dismiss(id: UUID) async throws

    /// Deletes every `InboxSuggestion` row whose status is `.pending`. Called
    /// from `ConnectionsViewModel.disconnectGmail` so a re-connect doesn't
    /// resurrect stale rows from a previous account.
    func clearPending() async throws
}

@MainActor
final class SwiftDataInboxStore: InboxStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func pending(forWeekOffset offset: Int, today: Date = .init()) async throws -> [InboxSuggestion] {
        let bounds = SwiftDataEventStore.weekBounds(forOffset: offset, today: today)
        let start = bounds.start
        let end = bounds.end
        let pendingRaw = InboxStatus.pending.rawValue
        let descriptor = FetchDescriptor<InboxSuggestion>(predicate: #Predicate<InboxSuggestion> {
            $0.statusRaw == pendingRaw && $0.proposedStart >= start && $0.proposedStart < end
        },
        sortBy: [SortDescriptor(\.proposedStart, order: .forward)])
        return try context.fetch(descriptor)
    }

    func suggestion(id: UUID) async throws -> InboxSuggestion? {
        try context.fetch(FetchDescriptor<InboxSuggestion>(predicate: #Predicate<InboxSuggestion> { $0.id == id }))
            .first
    }

    func upsert(_ suggestion: InboxSuggestion) async throws {
        let id = suggestion.id
        if let existing = try context
            .fetch(FetchDescriptor<InboxSuggestion>(predicate: #Predicate<InboxSuggestion> { $0.id == id })).first
        {
            existing.title = suggestion.title
            existing.proposedStart = suggestion.proposedStart
            existing.proposedEnd = suggestion.proposedEnd
            existing.fromName = suggestion.fromName
            existing.fromEmail = suggestion.fromEmail
            existing.categoryRaw = suggestion.categoryRaw
            existing.subject = suggestion.subject
            existing.bodySnippet = suggestion.bodySnippet
            existing.statusRaw = suggestion.statusRaw
        } else {
            context.insert(suggestion)
        }
        try context.save()
    }

    func accept(id: UUID) async throws {
        guard let suggestion = try await suggestion(id: id) else { return }
        suggestion.status = .accepted
        try context.save()
    }

    func dismiss(id: UUID) async throws {
        guard let suggestion = try await suggestion(id: id) else { return }
        suggestion.status = .dismissed
        try context.save()
    }

    func clearPending() async throws {
        let pendingRaw = InboxStatus.pending.rawValue
        let descriptor = FetchDescriptor<InboxSuggestion>(
            predicate: #Predicate<InboxSuggestion> { $0.statusRaw == pendingRaw }
        )
        for row in try context.fetch(descriptor) {
            context.delete(row)
        }
        try context.save()
    }
}
