import CoreLocation
import EventKit
import Foundation

/// Mapping between our `Event` and EventKit's `EKEvent`. Pure functions —
/// no side effects, no I/O, fully testable.
///
/// We round-trip custom planner-only fields (source, gmail provenance,
/// category fallback) through `EKEvent.notes` so a third-party calendar
/// client editing the event in Apple Calendar doesn't drop them. The format:
///
///     [...user notes...]
///     --planner-meta:{"source":"gmail","gmailMessageID":"abc",…}--
///
/// On read, we strip the suffix and decode. On write, we append the suffix
/// to whatever the user typed. The marker is short and tolerable in the
/// system Calendar UI; if a user manually deletes the marker we just fall
/// back to defaults.
enum EKEventMapping {
    private static let metaMarker = "--planner-meta:"
    private static let metaEnd = "--"

    /// Build (or update) an `EKEvent` from our `Event`. The caller supplies
    /// the EKEvent (either fresh from `gateway.newEvent()` or fetched by
    /// identifier) and the target `calendar`.
    static func apply(_ event: Event, to ekEvent: EKEvent, calendar: EKCalendar?) {
        ekEvent.title = event.title
        ekEvent.startDate = event.start
        ekEvent.endDate = event.end
        ekEvent.location = event.location
        if let calendar { ekEvent.calendar = calendar }
        ekEvent.notes = encodeNotes(forEvent: event)
        ekEvent.alarms = event.reminders.compactMap(makeAlarm(from:))
    }

    /// Build our `Event` from an `EKEvent`. `defaultCategory` is used when
    /// the meta blob is absent or unreadable (third-party events).
    static func toEvent(_ ekEvent: EKEvent,
                        defaultCategory: Category = .personal,
                        existingID: UUID? = nil) -> Event
    {
        let rawNotes = ekEvent.notes ?? ""
        let meta = decodeMeta(from: rawNotes)
        let userText = userNotes(from: rawNotes)
        return Event(id: existingID ?? UUID(),
                     eventKitIdentifier: ekEvent.eventIdentifier,
                     title: ekEvent.title ?? "",
                     start: ekEvent.startDate,
                     end: ekEvent.endDate,
                     location: ekEvent.location,
                     notes: userText.isEmpty ? nil : userText,
                     category: meta?.category ?? defaultCategory,
                     attendeesCount: ekEvent.attendees?.count ?? 0,
                     travelMinutes: nil,
                     source: meta?.source ?? .manual,
                     gmailMessageID: meta?.gmailMessageID,
                     gmailFrom: meta?.gmailFrom,
                     gmailSubject: meta?.gmailSubject,
                     reminders: (ekEvent.alarms ?? []).compactMap(makeReminder(from:)))
    }

    /// Strips the planner-meta blob so the user-facing notes are clean.
    /// Visible in `EKEvent.notes` after `decodeMeta` has read what it needs.
    static func userNotes(from rawNotes: String?) -> String {
        guard let rawNotes else { return "" }
        guard let range = rawNotes.range(of: metaMarker) else { return rawNotes }
        return String(rawNotes[..<range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Notes meta encoding

    private struct Meta: Codable {
        let source: EventSource?
        let category: Category?
        let gmailMessageID: String?
        let gmailFrom: String?
        let gmailSubject: String?
    }

    private static func encodeNotes(forEvent event: Event) -> String {
        let meta = Meta(source: event.source,
                        category: event.category,
                        gmailMessageID: event.gmailMessageID,
                        gmailFrom: event.gmailFrom,
                        gmailSubject: event.gmailSubject)
        let userBody = (event.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let data = try? JSONEncoder().encode(meta),
            let json = String(data: data, encoding: .utf8)
        else { return userBody }
        let marker = "\(metaMarker)\(json)\(metaEnd)"
        // Two newlines between the user's text and the meta marker so
        // Apple Calendar's UI renders the marker on its own line at the
        // tail of the notes pane.
        return userBody.isEmpty ? marker : "\(userBody)\n\n\(marker)"
    }

    static func decodeMeta(from notes: String) -> (source: EventSource?,
                                                   category: Category?,
                                                   gmailMessageID: String?,
                                                   gmailFrom: String?,
                                                   gmailSubject: String?)?
    {
        guard
            let markerRange = notes.range(of: metaMarker),
            let endRange = notes.range(of: metaEnd, range: markerRange.upperBound ..< notes.endIndex)
        else { return nil }
        let payload = notes[markerRange.upperBound ..< endRange.lowerBound]
        guard
            let data = payload.data(using: .utf8),
            let meta = try? JSONDecoder().decode(Meta.self, from: data)
        else { return nil }
        return (meta.source, meta.category, meta.gmailMessageID, meta.gmailFrom, meta.gmailSubject)
    }

    // MARK: - Reminder ↔ EKAlarm

    /// `Reminder.timeBefore` → negative `relativeOffset`. iOS uses positive
    /// `absoluteDate` for absolute alarms; we always emit relative.
    /// `Reminder.onArrive` → structured-location alarm with `.enter` proximity.
    static func makeAlarm(from reminder: Reminder) -> EKAlarm? {
        switch reminder {
        case let .timeBefore(minutes):
            return EKAlarm(relativeOffset: TimeInterval(-minutes * 60))
        case let .onArrive(location):
            let structuredLocation = EKStructuredLocation(title: location.name)
            structuredLocation.geoLocation = CLLocation(latitude: location.latitude,
                                                        longitude: location.longitude)
            structuredLocation.radius = location.radiusMeters
            let alarm = EKAlarm()
            alarm.structuredLocation = structuredLocation
            alarm.proximity = .enter
            return alarm
        }
    }

    static func makeReminder(from alarm: EKAlarm) -> Reminder? {
        if let structuredLocation = alarm.structuredLocation,
           let coord = structuredLocation.geoLocation
        {
            return .onArrive(LocationReminder(name: structuredLocation.title ?? "",
                                              latitude: coord.coordinate.latitude,
                                              longitude: coord.coordinate.longitude,
                                              radiusMeters: structuredLocation.radius))
        }
        // Time-before: alarm.relativeOffset is negative (seconds before start).
        let minutes = max(0, Int((-alarm.relativeOffset) / 60))
        return .timeBefore(minutes: minutes)
    }
}
