import EventKit
import Foundation

/// Decorates a base `EventStoring` so every write is mirrored out to
/// EventKit. Reads still go through the wrapped store — the on-disk
/// SwiftData copy is the source of truth.
///
/// Construction is wired up at app launch once Calendar permission is
/// granted (Phase 16); before then we use the bare SwiftData store.
@MainActor
final class EventKitMirroringEventStore: EventStoring {
    private let base: any EventStoring
    private let gateway: any EventKitGateway
    private let calendarManager: CategoryCalendarManager

    init(base: any EventStoring,
         gateway: any EventKitGateway,
         calendarManager: CategoryCalendarManager)
    {
        self.base = base
        self.gateway = gateway
        self.calendarManager = calendarManager
    }

    func events(forWeekOffset offset: Int, today: Date) async throws -> [Event] {
        try await base.events(forWeekOffset: offset, today: today)
    }

    func event(id: UUID) async throws -> Event? {
        try await base.event(id: id)
    }

    func upsert(_ event: Event) async throws {
        try await base.upsert(event)
        try? await mirrorToEventKit(event)
    }

    func delete(id: UUID) async throws {
        if let event = try await base.event(id: id), let identifier = event.eventKitIdentifier {
            removeFromEventKit(identifier: identifier)
        }
        try await base.delete(id: id)
    }

    func events(matching query: EventQuery) async throws -> [Event] {
        try await base.events(matching: query)
    }

    // MARK: - EventKit side effects (best-effort — failures don't roll back)

    private func mirrorToEventKit(_ event: Event) async throws {
        guard gateway.eventsAuthStatus.isFullAccess else { return }
        let calendars = try calendarManager.ensureCalendars()
        let target = calendars[event.category]

        let ekEvent: EKEvent = if let identifier = event.eventKitIdentifier,
                                  let existing = gateway.fetchEvents(from: event.start.addingTimeInterval(-86400),
                                                                     to: event.end.addingTimeInterval(86400),
                                                                     calendars: nil)
                                  .first(where: { $0.eventIdentifier == identifier })
        {
            existing
        } else {
            gateway.newEvent()
        }

        EKEventMapping.apply(event, to: ekEvent, calendar: target)
        try gateway.save(ekEvent)

        if event.eventKitIdentifier == nil, let identifier = ekEvent.eventIdentifier {
            event.eventKitIdentifier = identifier
            try? await base.upsert(event)
        }
    }

    private func removeFromEventKit(identifier: String) {
        guard gateway.eventsAuthStatus.isFullAccess else { return }
        let window = gateway.fetchEvents(from: Calendar.current.date(byAdding: .day, value: -365, to: Date()) ?? Date(),
                                         to: Calendar.current.date(byAdding: .day, value: 365, to: Date()) ?? Date(),
                                         calendars: nil)
        if let match = window.first(where: { $0.eventIdentifier == identifier }) {
            try? gateway.remove(match)
        }
    }
}
