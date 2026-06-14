import Foundation

/// Google Calendar API v3 `events.list` response (only fields we consume).
struct GCalEventsListResponse: Decodable {
    var items: [GCalEvent]
    var nextPageToken: String?
    var nextSyncToken: String?
}

struct GCalEvent: Decodable {
    let id: String
    /// "confirmed" | "tentative" | "cancelled". Cancelled drives a delete.
    let status: String?
    let summary: String?
    let location: String?
    let description: String?
    let start: GCalDateTime
    let end: GCalDateTime
    let etag: String?
    /// RFC3339 last-modified; used by Phase 37b for conflict resolution.
    let updated: String?
}

/// Google sends EITHER `date` (all-day, "yyyy-MM-dd") OR `dateTime` (RFC3339).
struct GCalDateTime: Decodable {
    let date: String?
    let dateTime: String?
}
