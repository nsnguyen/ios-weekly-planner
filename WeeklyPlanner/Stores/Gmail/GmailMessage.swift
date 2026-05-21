import Foundation

// MARK: - List response (GET /gmail/v1/users/me/messages)

struct GmailMessageListResponse: Decodable {
    let messages: [GmailMessageStub]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

struct GmailMessageStub: Decodable {
    let id: String
    let threadId: String?
}

// MARK: - Full message (GET /gmail/v1/users/me/messages/{id}?format=full)

struct GmailMessage: Decodable {
    let id: String
    let threadId: String?
    let snippet: String?
    let historyId: String?
    let internalDate: String?   // ms-since-epoch as a String
    let payload: GmailPayload?
}

struct GmailPayload: Decodable {
    let mimeType: String?
    let headers: [GmailHeader]
    let body: GmailBody?
    let parts: [GmailPayload]?
}

struct GmailHeader: Decodable {
    let name: String
    let value: String
}

struct GmailBody: Decodable {
    let size: Int?
    let data: String?           // base64url-encoded
}

// MARK: - History (GET /gmail/v1/users/me/history?startHistoryId=...)

struct GmailHistoryResponse: Decodable {
    let history: [GmailHistoryRecord]?
    let nextPageToken: String?
    let historyId: String?
}

struct GmailHistoryRecord: Decodable {
    let id: String
    let messages: [GmailMessageStub]?
    let messagesAdded: [GmailMessageAdded]?
}

struct GmailMessageAdded: Decodable {
    let message: GmailMessageStub
}

// MARK: - Profile (GET /gmail/v1/users/me/profile)

struct GmailProfile: Decodable {
    let emailAddress: String
    let historyId: String
    let messagesTotal: Int?
}

// MARK: - Convenience

extension GmailMessage {
    /// Returns the first header value matching `name` case-insensitively.
    func header(_ name: String) -> String? {
        payload?.headers.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.value
    }

    /// Best-effort plain-text body. Walks `parts` looking for `text/plain`;
    /// falls back to the top-level body, then to the snippet.
    func plainTextBody(maxBytes: Int = 3000) -> String {
        if let text = Self.findPart(in: payload, mimeType: "text/plain") {
            return String(text.prefix(maxBytes))
        }
        if let data = payload?.body?.data, let decoded = Self.decodeBase64URL(data) {
            return String(decoded.prefix(maxBytes))
        }
        return snippet ?? ""
    }

    private static func findPart(in payload: GmailPayload?, mimeType: String) -> String? {
        guard let payload else { return nil }
        if payload.mimeType?.lowercased() == mimeType,
           let data = payload.body?.data,
           let decoded = decodeBase64URL(data)
        {
            return decoded
        }
        for part in payload.parts ?? [] {
            if let found = findPart(in: part, mimeType: mimeType) { return found }
        }
        return nil
    }

    private static func decodeBase64URL(_ raw: String) -> String? {
        var s = raw.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }
        guard let data = Data(base64Encoded: s) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
