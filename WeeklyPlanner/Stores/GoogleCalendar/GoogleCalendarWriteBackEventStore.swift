import Foundation
import os

private let writeBackLog = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "GCalWriteBack")

/// Decorates the local event store with Google Calendar write-back.
///
/// Create-only for Task 5: new, non-recurring local events are POSTed to Google
/// when Calendar is connected. The returned remote identity is applied before
/// persistence so the EventKit mirror sees `.googleCalendar` and skips the loop.
@MainActor
final class GoogleCalendarWriteBackEventStore: EventStoring {
    private let base: any EventStoring
    private let client: any GoogleCalendarClientProtocol
    private let settingsStore: any SettingsStoring

    init(
        base: any EventStoring,
        client: any GoogleCalendarClientProtocol,
        settingsStore: any SettingsStoring
    ) {
        self.base = base
        self.client = client
        self.settingsStore = settingsStore
    }

    func events(forWeekOffset offset: Int, today: Date) async throws -> [Event] {
        try await base.events(forWeekOffset: offset, today: today)
    }

    func event(id: UUID) async throws -> Event? {
        try await base.event(id: id)
    }

    func upsert(_ event: Event) async throws {
        if event.googleEventID == nil, shouldWriteBack(event) {
            do {
                let remote = try await client.createEvent(GCalMapper.writeBody(from: event))
                applyRemoteIdentity(remote, to: event)
            } catch {
                writeBackLog.error("GCal create write-back failed for event \(event.id.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
                NotificationCenter.default.post(
                    name: .googleCalendarWriteBackDidFail,
                    object: event,
                    userInfo: ["error": error]
                )
            }
        }

        try await base.upsert(event)
    }

    func delete(id: UUID) async throws {
        // Task 7 owns remote cancellation. For now deletes remain local passthrough.
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
        isConnected &&
            !GCalWriteBackContext.suppressWriteBack &&
            event.recurrence == nil
    }

    private var isConnected: Bool {
        (try? settingsStore.current().googleCalendarConnected) == true
    }

    private func applyRemoteIdentity(_ remote: GCalEvent, to event: Event) {
        event.googleEventID = remote.id
        event.googleEtag = remote.etag
        event.source = .googleCalendar
        event.eventKitIdentifier = nil
        if let updatedAt = Self.parseUpdated(remote.updated) {
            event.updatedAt = updatedAt
        }
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
