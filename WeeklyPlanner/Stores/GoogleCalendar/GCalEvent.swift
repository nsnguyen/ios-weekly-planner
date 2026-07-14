import Foundation

/// Google Calendar API v3 `events.list` response (only fields we consume).
struct GCalEventsListResponse: Decodable {
    var items: [GCalEvent]
    var nextPageToken: String?
    var nextSyncToken: String?

    init(items: [GCalEvent], nextPageToken: String?, nextSyncToken: String?) {
        self.items = items
        self.nextPageToken = nextPageToken
        self.nextSyncToken = nextSyncToken
    }

    private enum CodingKeys: String, CodingKey { case items, nextPageToken, nextSyncToken }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([GCalEvent].self, forKey: .items) ?? []
        nextPageToken = try c.decodeIfPresent(String.self, forKey: .nextPageToken)
        nextSyncToken = try c.decodeIfPresent(String.self, forKey: .nextSyncToken)
    }
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

/// Request body for create/update. Only fields we author.
struct GCalEventWriteBody: Encodable, Equatable {
    var summary: String
    var location: String?
    var description: String?
    var start: GCalDateTime
    var end: GCalDateTime
}

/// Google sends EITHER `date` (all-day, "yyyy-MM-dd") OR `dateTime` (RFC3339).
struct GCalDateTime: Codable, Equatable {
    let date: String?
    let dateTime: String?
}
