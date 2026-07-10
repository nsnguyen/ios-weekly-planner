import Foundation
import SwiftData

/// Read / write access to events. Implemented by `SwiftDataEventStore` in
/// production; Phase 04 wraps this with `EventStore+EventKit` to mirror
/// writes out to the system Calendar.
@MainActor
protocol EventStoring: AnyObject {
    func events(forWeekOffset offset: Int, today: Date) async throws -> [Event]
    func event(id: UUID) async throws -> Event?
    func upsert(_ event: Event) async throws
    func delete(id: UUID) async throws

    /// Removes ONE occurrence of a recurring series ("delete this event
    /// only"). No-op for single events.
    func deleteOccurrence(eventID: UUID, occurrenceStart: Date) async throws

    /// Returns events inside `query.dateRange` filtered by the optional
    /// category / keyword / person-name axes. Used by the Intelligence
    /// layer (Phase 13) so the model can ask narrower questions than
    /// `events(forWeekOffset:)`.
    func events(matching query: EventQuery) async throws -> [Event]

    /// Returns all events whose `source` matches `source`. Used by
    /// `GCalSyncEngine.purge()` to remove only Google-Calendar-sourced events.
    func events(source: EventSource) async throws -> [Event]
}

// View-side observation: SwiftUI views read events via `@Query` directly
// from the `ModelContainer`. Cross-actor `AsyncStream<[Event]>` is added
// in Phase 06 once the snapshot DTOs are designed.

@MainActor
final class SwiftDataEventStore: EventStoring {
    private let context: ModelContext
    /// Used to fan changes out to `observe(weekOffset:)` callers.
    private let changeSubject = NotificationCenter.default

    init(context: ModelContext) {
        self.context = context
    }

    func events(forWeekOffset offset: Int, today: Date = .init()) async throws -> [Event] {
        let bounds = Self.weekBounds(forOffset: offset, today: today)
        let start = bounds.start
        let end = bounds.end

        // Single events: start-in-window, as before — recurring masters
        // are excluded here and expanded below instead.
        let singlesDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.start >= start && $0.start < end && !$0.isRecurring },
            sortBy: [SortDescriptor(\.start, order: .forward)])
        let singles = try context.fetch(singlesDescriptor)

        // Recurring series: expand into this window (transient copies).
        let recurringDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.isRecurring })
        let masters = try context.fetch(recurringDescriptor)
        let calendar = WeekMath.mondayCalendar()
        let occurrences = masters.flatMap {
            OccurrenceExpander.occurrences(of: $0, in: start ..< end, calendar: calendar)
        }

        return (singles + occurrences).sorted { $0.start < $1.start }
    }

    func event(id: UUID) async throws -> Event? {
        let descriptor = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == id })
        return try context.fetch(descriptor).first
    }

    func upsert(_ event: Event) async throws {
        let id = event.id
        let existing = try context.fetch(FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == id })).first

        if let existing {
            existing.title = event.title
            existing.start = event.start
            existing.end = event.end
            existing.location = event.location
            existing.notes = event.notes
            existing.categoryRaw = event.categoryRaw
            existing.attendeesCount = event.attendeesCount
            existing.travelMinutes = event.travelMinutes
            existing.sourceRaw = event.sourceRaw
            existing.gmailMessageID = event.gmailMessageID
            existing.gmailFrom = event.gmailFrom
            existing.gmailSubject = event.gmailSubject
            existing.googleEventID = event.googleEventID
            existing.googleEtag = event.googleEtag
            existing.reminders = event.reminders
            existing.recurrence = event.recurrence
            existing.isRecurring = event.recurrence != nil
            existing.excludedOccurrenceStarts = event.excludedOccurrenceStarts
            existing.eventKitIdentifier = event.eventKitIdentifier
            existing.updatedAt = event.updatedAt
        } else {
            context.insert(event)
        }

        try context.save()
        changeSubject.post(name: .eventStoreDidChange, object: nil)
    }

    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == id })
        if let event = try context.fetch(descriptor).first {
            context.delete(event)
            try context.save()
            changeSubject.post(name: .eventStoreDidChange, object: nil)
        }
    }

    func deleteOccurrence(eventID: UUID, occurrenceStart: Date) async throws {
        guard let event = try await event(id: eventID), event.isRecurring else { return }
        event.excludedOccurrenceStarts.append(occurrenceStart)
        event.updatedAt = .init()
        try context.save()
        changeSubject.post(name: .eventStoreDidChange, object: nil)
    }

    func events(matching query: EventQuery) async throws -> [Event] {
        let start = query.dateRange.lowerBound
        let end = query.dateRange.upperBound
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.start >= start && $0.start <= end },
            sortBy: [SortDescriptor(\.start, order: .forward)]
        )
        let raw = try context.fetch(descriptor)
        return raw.filter { event in
            if let categories = query.categories, !categories.isEmpty {
                guard categories.contains(where: { $0.rawValue == event.categoryRaw }) else { return false }
            }
            if !query.keywords.isEmpty {
                let lowered = event.title.lowercased()
                guard query.keywords.contains(where: { lowered.contains($0.lowercased()) }) else { return false }
            }
            if let person = query.personName, !person.isEmpty {
                let lowered = event.title.lowercased()
                guard lowered.contains(person.lowercased()) else { return false }
            }
            return true
        }
    }

    func events(source: EventSource) async throws -> [Event] {
        let raw = source.rawValue
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.sourceRaw == raw },
            sortBy: [SortDescriptor(\.start, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Week bounds helper

    static func weekBounds(forOffset offset: Int, today: Date) -> (start: Date, end: Date) {
        let calendar = WeekMath.mondayCalendar()
        let mondayThisWeek = mondayOfWeek(containing: today, calendar: calendar)
        let mondayTarget = calendar.date(byAdding: .day, value: 7 * offset, to: mondayThisWeek) ?? mondayThisWeek
        let mondayNext = calendar.date(byAdding: .day, value: 7, to: mondayTarget) ?? mondayTarget
        return (mondayTarget, mondayNext)
    }

    private static func mondayOfWeek(containing date: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay) ?? startOfDay
    }
}

extension Notification.Name {
    static let eventStoreDidChange = Notification.Name("WeeklyPlanner.EventStore.didChange")
}
