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
        // Phase 37: Google-sourced events are read-only imports that live only in
        // SwiftData (and Google). Never mirror them to iOS Calendar — that would
        // loop back through the EventKit reconciler. One source of truth per source.
        guard event.source != .googleCalendar else { try await base.upsert(event); return }
        try await base.upsert(event)
        try? await mirrorToEventKit(event)
    }

    func delete(id: UUID) async throws {
        if let event = try await base.event(id: id) {
            // Phase 37: Google-sourced events have no EKEvent to remove.
            // Delegate to base and return immediately to prevent any gateway call.
            guard event.source != .googleCalendar else { try await base.delete(id: id); return }
            if let identifier = event.eventKitIdentifier {
                // Recurring deletes are anchored at the master, so `.futureEvents`
                // removes the whole series; singles use `.thisEvent`.
                let span: EKSpan = event.recurrence != nil ? .futureEvents : .thisEvent
                removeFromEventKit(identifier: identifier, span: span)
            }
        }
        try await base.delete(id: id)
    }

    func deleteOccurrence(eventID: UUID, occurrenceStart: Date) async throws {
        // EK detach is best-effort; the local exclusion is the source of truth.
        if let event = try await base.event(id: eventID),
           let identifier = event.eventKitIdentifier,
           gateway.eventsAuthStatus.isFullAccess
        {
            let duration = max(event.end.timeIntervalSince(event.start), 60)
            let candidates = gateway.fetchEvents(from: occurrenceStart.addingTimeInterval(-60),
                                                 to: occurrenceStart.addingTimeInterval(duration + 60),
                                                 calendars: nil)
            if let occurrence = candidates.first(where: {
                $0.eventIdentifier == identifier &&
                    abs($0.startDate.timeIntervalSince(occurrenceStart)) < 60
            }) {
                try? gateway.remove(occurrence, span: .thisEvent)
            }
        }
        try await base.deleteOccurrence(eventID: eventID, occurrenceStart: occurrenceStart)
    }

    func events(matching query: EventQuery) async throws -> [Event] {
        try await base.events(matching: query)
    }

    func events(source: EventSource) async throws -> [Event] {
        try await base.events(source: source)
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
        let span: EKSpan = event.recurrence != nil ? .futureEvents : .thisEvent
        try gateway.save(ekEvent, span: span)

        if event.eventKitIdentifier == nil, let identifier = ekEvent.eventIdentifier {
            event.eventKitIdentifier = identifier
            try? await base.upsert(event)
        }
    }

    private func removeFromEventKit(identifier: String, span: EKSpan = .thisEvent) {
        guard gateway.eventsAuthStatus.isFullAccess else { return }
        let window = gateway.fetchEvents(from: Calendar.current.date(byAdding: .day, value: -365, to: Date()) ?? Date(),
                                         to: Calendar.current.date(byAdding: .day, value: 365, to: Date()) ?? Date(),
                                         calendars: nil)
        if let match = window.first(where: { $0.eventIdentifier == identifier }) {
            try? gateway.remove(match, span: span)
        }
    }
}
