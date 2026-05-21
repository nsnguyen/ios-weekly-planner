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

    /// Returns the suggestion with the given gmailMessageID regardless of
    /// status (pending/accepted/dismissed). Used by InboxSyncEngine to
    /// skip messages it has already handled in a previous sync.
    func anyStatus(forMessageID id: String) async throws -> InboxSuggestion?
}

@MainActor
final class SwiftDataInboxStore: InboxStoring {
    private let context: ModelContext
    private let eventStore: (any EventStoring)?
    private let settingsStore: (any SettingsStoring)?

    init(
        context: ModelContext,
        eventStore: (any EventStoring)? = nil,
        settingsStore: (any SettingsStoring)? = nil
    ) {
        self.context = context
        self.eventStore = eventStore
        self.settingsStore = settingsStore
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

        // If we have an EventStore, mirror the suggestion to a real Event
        // (Phase 18 wires this; Phase 17 tests / previews pass nil and we
        // just flip the status).
        if let eventStore {
            let endDate = suggestion.proposedEnd ?? suggestion.proposedStart.addingTimeInterval(3600)
            let event = Event(
                title: suggestion.title,
                start: suggestion.proposedStart,
                end: endDate,
                location: suggestion.proposedLocation,
                category: suggestion.category,
                source: .gmail,
                gmailMessageID: suggestion.gmailMessageID,
                gmailFrom: suggestion.fromEmail,
                gmailSubject: suggestion.subject
            )
            if let settings = try? settingsStore?.current() {
                DefaultReminderPolicy.apply(to: event, settings: settings)
            }
            try await eventStore.upsert(event)
        }

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

    func anyStatus(forMessageID id: String) async throws -> InboxSuggestion? {
        try context.fetch(FetchDescriptor<InboxSuggestion>(
            predicate: #Predicate<InboxSuggestion> { $0.gmailMessageID == id }
        )).first
    }
}
