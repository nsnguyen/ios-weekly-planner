import Foundation

@MainActor
protocol GmailClientProtocol: AnyObject {
    func listMessages(query: String, maxResults: Int) async throws -> [GmailMessageStub]
    func fetchMessage(id: String, format: GmailMessageFormat) async throws -> GmailMessage
    func history(startHistoryId: String) async throws -> GmailHistoryResponse
    func profile() async throws -> GmailProfile
}

extension GmailClient: GmailClientProtocol {}

enum GmailClientError: Error, Equatable {
    /// The Gmail history cursor we passed is too old. Caller should do a full re-sync.
    case historyExpired
    /// Server returned non-success after retries.
    case http(status: Int)
    /// Response body wasn't valid JSON for the expected DTO.
    case decode(String)
}

enum GmailMessageFormat: String {
    case full
    case metadata
    case minimal
}

/// REST wrapper for Gmail API v1. Handles bearer-token injection,
/// automatic refresh on 401 (one retry), and `Retry-After`-aware
/// backoff on 429 (up to 5 retries with jitter). Network transport is
/// injected via `URLSessionProtocol` so tests use `URLProtocolStub`.
@MainActor
final class GmailClient {
    private let auth: any GoogleAuthService
    private let session: URLSessionProtocol
    private let baseURL = URL(string: "https://gmail.googleapis.com")!
    private static let maxRetries = 5

    init(auth: any GoogleAuthService, session: URLSessionProtocol) {
        self.auth = auth
        self.session = session
    }

    // MARK: - Public endpoints

    func listMessages(query: String, maxResults: Int) async throws -> [GmailMessageStub] {
        var components = URLComponents(url: baseURL.appending(path: "/gmail/v1/users/me/messages"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
        ]
        let response: GmailMessageListResponse = try await get(url: components.url!)
        return response.messages ?? []
    }

    func fetchMessage(id: String, format: GmailMessageFormat) async throws -> GmailMessage {
        var components = URLComponents(url: baseURL.appending(path: "/gmail/v1/users/me/messages/\(id)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "format", value: format.rawValue)]
        return try await get(url: components.url!)
    }

    func history(startHistoryId: String) async throws -> GmailHistoryResponse {
        var components = URLComponents(url: baseURL.appending(path: "/gmail/v1/users/me/history"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "startHistoryId", value: startHistoryId)]
        do {
            return try await get(url: components.url!)
        } catch GmailClientError.http(status: 404) {
            throw GmailClientError.historyExpired
        }
    }

    func profile() async throws -> GmailProfile {
        let url = baseURL.appending(path: "/gmail/v1/users/me/profile")
        return try await get(url: url)
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
                    throw GmailClientError.decode(String(describing: error))
                }

            case 401:
                if did401 {
                    throw GoogleAuthError.reauthenticationRequired
                }
                did401 = true
                continue // auth.accessToken() will refresh on the next call

            case 429:
                if attempts > Self.maxRetries {
                    throw GmailClientError.http(status: 429)
                }
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? pow(2.0, Double(attempts))
                try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                continue

            default:
                throw GmailClientError.http(status: http.statusCode)
            }
        }
    }
}
