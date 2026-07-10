import CryptoKit
import Foundation

/// Pure mapping Google Calendar event → app `Event`. Returns nil for
/// cancelled items (the caller deletes them by deterministic id).
enum GCalMapper {
    /// Stable `Event.id` from a Google event id: SHA-256 → first 16 bytes → UUID.
    /// Same google id ⇒ same Event.id, so `EventStoring.upsert` (dedup-by-id)
    /// updates rather than duplicates on every re-sync.
    static func deterministicID(for googleEventID: String) -> UUID {
        let digest = SHA256.hash(data: Data(googleEventID.utf8))
        let b = Array(digest.prefix(16))
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

    static func event(from g: GCalEvent) -> Event? {
        guard g.status != "cancelled" else { return nil }
        guard let start = parse(g.start), let end = parse(g.end) else { return nil }
        return Event(id: deterministicID(for: g.id),
                     title: g.summary.flatMap { $0.isEmpty ? nil : $0 } ?? "(no title)",
                     start: start,
                     end: max(end, start),
                     location: g.location,
                     notes: g.description,
                     category: .personal,
                     source: .googleCalendar,
                     googleEventID: g.id,
                     googleEtag: g.etag,
                     updatedAt: parseUpdated(g.updated) ?? Date())
    }

    static func writeBody(from event: Event) -> GCalEventWriteBody {
        if isAllDay(event) {
            return GCalEventWriteBody(summary: event.title,
                                      location: event.location,
                                      description: event.notes,
                                      start: GCalDateTime(date: dayString(from: event.start), dateTime: nil),
                                      end: GCalDateTime(date: dayString(from: event.end), dateTime: nil))
        }

        return GCalEventWriteBody(summary: event.title,
                                  location: event.location,
                                  description: event.notes,
                                  start: GCalDateTime(date: nil, dateTime: iso.string(from: event.start)),
                                  end: GCalDateTime(date: nil, dateTime: iso.string(from: event.end)))
    }

    private nonisolated(unsafe) static let iso = ISO8601DateFormatter()
    private nonisolated(unsafe) static let day: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func isAllDay(_ event: Event) -> Bool {
        let calendar = Calendar.current
        return event.end > event.start
            && event.start == calendar.startOfDay(for: event.start)
            && event.end == calendar.startOfDay(for: event.end)
    }

    private static func dayString(from date: Date) -> String {
        day.string(from: date)
    }

    private static func parseUpdated(_ value: String?) -> Date? {
        guard let value else { return nil }
        return iso.date(from: value)
    }

    private static func parse(_ dt: GCalDateTime) -> Date? {
        if let s = dt.dateTime { return iso.date(from: s) }
        if let d = dt.date { return day.date(from: d) }   // all-day → local midnight
        return nil
    }
}
