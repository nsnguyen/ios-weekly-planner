import Foundation
import os

/// Subsystem logger for the Calendar REST client. Mirrors `GCalSyncEngine`'s
/// `syncLog` so API failures are diagnosable — in particular a 403/4xx body,
/// which names the exact cause (API-not-enabled vs insufficient-scope) and is
/// otherwise discarded.
private let clientLog = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "GCalClient")

@MainActor
protocol GoogleCalendarClientProtocol: AnyObject {
    func listEvents(syncToken: String?, timeMin: Date?, timeMax: Date?, pageToken: String?) async throws -> GCalEventsListResponse
    func getEvent(id: String) async throws -> GCalEvent
    func createEvent(_ body: GCalEventWriteBody) async throws -> GCalEvent
    func updateEvent(id: String, body: GCalEventWriteBody, etag: String?) async throws -> GCalEvent
    func cancelEvent(id: String) async throws
}
extension GoogleCalendarClient: GoogleCalendarClientProtocol {}

enum GoogleCalendarClientError: Error, Equatable {
    /// The sync token we passed is too old. Caller should do a full re-sync.
    case syncTokenExpired   // 410 Gone
    /// Caller attempted to update an event whose remote etag has changed.
    case preconditionFailed // 412 Precondition Failed
    /// The requested remote event no longer exists.
    case notFound           // 404 Not Found
    /// Server returned non-success after retries.
    case http(status: Int)
    /// Response body wasn't valid JSON for the expected DTO.
    case decode(String)
}

/// REST wrapper for Google Calendar API v3. Handles bearer-token injection,
/// automatic refresh on 401 (one retry), and `Retry-After`-aware backoff on
/// 429 (up to 5 retries). Network transport is injected via `URLSessionProtocol`
/// so tests use `URLProtocolStub`.
@MainActor
final class GoogleCalendarClient {
    private let auth: any GoogleAuthService
    private let session: URLSessionProtocol
    private let baseURL = URL(string: "https://www.googleapis.com")!
    private static let maxRetries = 5

    init(auth: any GoogleAuthService, session: URLSessionProtocol) {
        self.auth = auth
        self.session = session
    }

    // MARK: - Public endpoints

    func listEvents(syncToken: String?, timeMin: Date?, timeMax: Date?, pageToken: String?) async throws -> GCalEventsListResponse {
        var c = URLComponents(url: baseURL.appending(path: "/calendar/v3/calendars/primary/events"), resolvingAgainstBaseURL: false)!
        var q = [URLQueryItem(name: "singleEvents", value: "true"),
                 URLQueryItem(name: "maxResults", value: "250")]
        if let syncToken {
            // incremental sync: timeMin/Max not allowed alongside syncToken
            q.append(URLQueryItem(name: "syncToken", value: syncToken))
        } else {
            // full sync: bound the window
            let iso = ISO8601DateFormatter()
            if let timeMin { q.append(URLQueryItem(name: "timeMin", value: iso.string(from: timeMin))) }
            if let timeMax { q.append(URLQueryItem(name: "timeMax", value: iso.string(from: timeMax))) }
        }
        if let pageToken { q.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        c.queryItems = q
        do {
            return try await send(url: c.url!, method: "GET", body: nil, ifMatch: nil)
        } catch GoogleCalendarClientError.http(status: 410) {
            throw GoogleCalendarClientError.syncTokenExpired
        }
    }

    func getEvent(id: String) async throws -> GCalEvent {
        let url = baseURL.appending(path: "/calendar/v3/calendars/primary/events/\(id)")
        do {
            return try await send(url: url, method: "GET", body: nil, ifMatch: nil)
        } catch GoogleCalendarClientError.http(status: 404) {
            throw GoogleCalendarClientError.notFound
        }
    }

    func createEvent(_ body: GCalEventWriteBody) async throws -> GCalEvent {
        let url = baseURL.appending(path: "/calendar/v3/calendars/primary/events")
        let data = try JSONEncoder().encode(body)
        return try await send(url: url, method: "POST", body: data, ifMatch: nil)
    }

    func updateEvent(id: String, body: GCalEventWriteBody, etag: String?) async throws -> GCalEvent {
        let url = baseURL.appending(path: "/calendar/v3/calendars/primary/events/\(id)")
        let data = try JSONEncoder().encode(body)
        do {
            return try await send(url: url, method: "PUT", body: data, ifMatch: etag)
        } catch GoogleCalendarClientError.http(status: 412) {
            throw GoogleCalendarClientError.preconditionFailed
        }
    }

    func cancelEvent(id: String) async throws {
        let url = baseURL.appending(path: "/calendar/v3/calendars/primary/events/\(id)")
        let data = try JSONSerialization.data(withJSONObject: ["status": "cancelled"])
        do {
            let _: GCalEvent = try await send(url: url, method: "PATCH", body: data, ifMatch: nil)
        } catch GoogleCalendarClientError.http(status: 404) {
            throw GoogleCalendarClientError.notFound
        }
    }

    // MARK: - Private

    private func send<T: Decodable>(url: URL, method: String, body: Data?, ifMatch: String?) async throws -> T {
        var did401 = false
        var attempts = 0

        while true {
            attempts += 1
            let token = try await auth.accessToken()
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let body {
                request.httpBody = body
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            if let ifMatch {
                request.setValue(ifMatch, forHTTPHeaderField: "If-Match")
            }

            let (data, response) = try await session.data(for: request)
            let http = response as! HTTPURLResponse

            switch http.statusCode {
            case 200..<300:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    throw GoogleCalendarClientError.decode(String(describing: error))
                }

            case 401:
                if did401 {
                    throw GoogleAuthError.reauthenticationRequired
                }
                did401 = true
                continue // auth.accessToken() will refresh on the next call

            case 429:
                if attempts > Self.maxRetries {
                    throw GoogleCalendarClientError.http(status: 429)
                }
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? pow(2.0, Double(attempts))
                try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                continue

            default:
                // Surface the API error body — Google's 4xx JSON names the exact
                // reason (e.g. "accessNotConfigured" + an enable URL, or
                // "ACCESS_TOKEN_SCOPE_INSUFFICIENT"). Without this it's an opaque
                // status code.
                let body = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes, non-utf8>"
                clientLog.error("GCal API \(http.statusCode, privacy: .public) at \(url.path, privacy: .public): \(body, privacy: .public)")
                throw GoogleCalendarClientError.http(status: http.statusCode)
            }
        }
    }
}
