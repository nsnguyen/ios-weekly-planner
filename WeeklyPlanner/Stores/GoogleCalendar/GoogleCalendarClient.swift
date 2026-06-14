import Foundation

@MainActor
protocol GoogleCalendarClientProtocol: AnyObject {
    func listEvents(syncToken: String?, timeMin: Date?, timeMax: Date?, pageToken: String?) async throws -> GCalEventsListResponse
}
extension GoogleCalendarClient: GoogleCalendarClientProtocol {}

enum GoogleCalendarClientError: Error, Equatable {
    /// The sync token we passed is too old. Caller should do a full re-sync.
    case syncTokenExpired   // 410 Gone
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
            return try await get(url: c.url!)
        } catch GoogleCalendarClientError.http(status: 410) {
            throw GoogleCalendarClientError.syncTokenExpired
        }
    }

    // MARK: - Private

    private func get<T: Decodable>(url: URL) async throws -> T {
        var did401 = false
        var attempts = 0

        while true {
            attempts += 1
            let token = try await auth.accessToken()
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

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
                throw GoogleCalendarClientError.http(status: http.statusCode)
            }
        }
    }
}
