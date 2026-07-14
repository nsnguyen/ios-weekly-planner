import Foundation
import os

private let writeBackLog = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "GCalWriteBack")

/// Decorates the local event store with Google Calendar write-back.
///
/// New, non-recurring local events are POSTed to Google when Calendar is
/// connected. Existing Google-backed events use last-write-wins update
/// semantics before local persistence.
@MainActor
final class GoogleCalendarWriteBackEventStore: EventStoring {
    private let base: any EventStoring
    private let client: any GoogleCalendarClientProtocol
    private let isConnected: @MainActor () -> Bool
    private let unlinkEventKitIdentifier: @MainActor (String) -> Void

    init(
        base: any EventStoring,
        client: any GoogleCalendarClientProtocol,
        isConnected: @escaping @MainActor () -> Bool,
        unlinkEventKitIdentifier: @escaping @MainActor (String) -> Void
    ) {
        self.base = base
        self.client = client
        self.isConnected = isConnected
        self.unlinkEventKitIdentifier = unlinkEventKitIdentifier
    }

    func events(forWeekOffset offset: Int, today: Date) async throws -> [Event] {
        try await base.events(forWeekOffset: offset, today: today)
    }

    func event(id: UUID) async throws -> Event? {
        try await base.event(id: id)
    }

    func upsert(_ event: Event) async throws {
        if shouldWriteBack(event) {
            do {
                if let googleEventID = event.googleEventID {
                    try await pushUpdate(event, googleEventID: googleEventID, allowRetry: true)
                } else {
                    let remote = try await client.createEvent(GCalMapper.writeBody(from: event))
                    applyRemoteIdentity(remote, to: event)
                }
            } catch {
                reportWriteBackFailure(error, event: event)
            }
        }

        try await base.upsert(event)
    }

    func delete(id: UUID) async throws {
        if let event = try await base.event(id: id),
           shouldWriteBack(event),
           let googleEventID = event.googleEventID {
            do {
                try await client.cancelEvent(id: googleEventID)
            } catch GoogleCalendarClientError.notFound {
                // The remote is already gone; local deletion should still win.
            } catch {
                reportWriteBackFailure(error, event: event)
            }
        }

        try await base.delete(id: id)
    }

    func deleteOccurrence(eventID: UUID, occurrenceStart: Date) async throws {
        try await base.deleteOccurrence(eventID: eventID, occurrenceStart: occurrenceStart)
    }

    func events(matching query: EventQuery) async throws -> [Event] {
        try await base.events(matching: query)
    }

    func events(source: EventSource) async throws -> [Event] {
        try await base.events(source: source)
    }

    private func shouldWriteBack(_ event: Event) -> Bool {
        isConnected() &&
            !GCalWriteBackContext.suppressWriteBack &&
            event.recurrence == nil
    }

    private func pushUpdate(_ event: Event, googleEventID: String, allowRetry: Bool) async throws {
        let remote = try await client.getEvent(id: googleEventID)
        if remoteIsNewer(remote, than: event) {
            applyMappedRemote(remote, to: event)
            return
        }

        do {
            let updated = try await client.updateEvent(
                id: googleEventID,
                body: GCalMapper.writeBody(from: event),
                etag: remote.etag ?? event.googleEtag
            )
            applyRemoteIdentity(updated, to: event)
        } catch GoogleCalendarClientError.preconditionFailed where allowRetry {
            let fresh = try await client.getEvent(id: googleEventID)
            if remoteIsNewer(fresh, than: event) {
                applyMappedRemote(fresh, to: event)
            } else {
                try await pushUpdate(event, googleEventID: googleEventID, allowRetry: false)
            }
        }
    }

    private func applyRemoteIdentity(_ remote: GCalEvent, to event: Event) {
        event.googleEventID = remote.id
        event.googleEtag = remote.etag
        flipToGoogleCalendarSource(event)
        if let updatedAt = Self.parseUpdated(remote.updated) {
            event.updatedAt = updatedAt
        }
    }

    private func applyMappedRemote(_ remote: GCalEvent, to event: Event) {
        guard let mapped = GCalMapper.event(from: remote) else { return }
        event.title = mapped.title
        event.start = mapped.start
        event.end = mapped.end
        event.location = mapped.location
        event.notes = mapped.notes
        event.googleEventID = mapped.googleEventID
        event.googleEtag = mapped.googleEtag
        flipToGoogleCalendarSource(event)
        event.updatedAt = mapped.updatedAt
    }

    private func flipToGoogleCalendarSource(_ event: Event) {
        let eventKitIdentifier = event.eventKitIdentifier
        event.source = .googleCalendar
        event.eventKitIdentifier = nil
        if let eventKitIdentifier {
            unlinkEventKitIdentifier(eventKitIdentifier)
        }
    }

    private func remoteIsNewer(_ remote: GCalEvent, than event: Event) -> Bool {
        guard let remoteUpdatedAt = Self.parseUpdated(remote.updated) else { return false }
        return remoteUpdatedAt > event.updatedAt
    }

    private func reportWriteBackFailure(_ error: Error, event: Event) {
        writeBackLog.error("GCal write-back failed for event \(event.id.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
        NotificationCenter.default.post(
            name: .googleCalendarWriteBackDidFail,
            object: event,
            userInfo: ["error": error]
        )
    }

    private nonisolated(unsafe) static let iso = ISO8601DateFormatter()
    private nonisolated(unsafe) static let isoWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func parseUpdated(_ value: String?) -> Date? {
        guard let value else { return nil }
        return isoWithFractionalSeconds.date(from: value) ?? iso.date(from: value)
    }
}

extension Notification.Name {
    static let googleCalendarWriteBackDidFail = Notification.Name("WeeklyPlanner.GoogleCalendar.writeBackDidFail")
}
