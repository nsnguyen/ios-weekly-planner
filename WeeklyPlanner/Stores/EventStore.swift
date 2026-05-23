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

    /// Returns events inside `query.dateRange` filtered by the optional
    /// category / keyword / person-name axes. Used by the Intelligence
    /// layer (Phase 13) so the model can ask narrower questions than
    /// `events(forWeekOffset:)`.
    func events(matching query: EventQuery) async throws -> [Event]
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
        let descriptor = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.start >= start && $0.start < end },
                                                sortBy: [SortDescriptor(\.start, order: .forward)])
        return try context.fetch(descriptor)
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
            existing.reminders = event.reminders
            existing.eventKitIdentifier = event.eventKitIdentifier
            existing.updatedAt = .init()
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
