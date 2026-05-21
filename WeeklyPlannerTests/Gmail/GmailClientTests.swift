import XCTest
@testable import WeeklyPlanner

@MainActor
final class GmailClientTests: XCTestCase {
    private var fakeAuth: RecordingAuthService!
    private var session: URLSession!
    private var sut: GmailClient!

    override func setUp() async throws {
        try await super.setUp()
        fakeAuth = RecordingAuthService(token: "test-token")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        session = URLSession(configuration: config)
        URLProtocolStub.reset()
        sut = GmailClient(auth: fakeAuth, session: session)
    }

    override func tearDown() async throws {
        URLProtocolStub.reset()
        try await super.tearDown()
    }

    func testListMessagesEncodesQueryAndBearer() async throws {
        URLProtocolStub.respond { request in
            XCTAssertEqual(request.url?.path, "/gmail/v1/users/me/messages")
            XCTAssertEqual(request.url?.query?.contains("q=from:resy"), true)
            XCTAssertEqual(request.url?.query?.contains("maxResults=50"), true)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            return URLProtocolStub.Response(
                status: 200,
                data: #"{"messages":[{"id":"abc","threadId":"t1"}]}"#.data(using: .utf8)!
            )
        }

        let stubs = try await sut.listMessages(query: "from:resy", maxResults: 50)

        XCTAssertEqual(stubs.count, 1)
        XCTAssertEqual(stubs.first?.id, "abc")
    }

    func testFetchMessageRetriesOn429WithRetryAfter() async throws {
        var calls = 0
        URLProtocolStub.respond { _ in
            calls += 1
            if calls == 1 {
                return URLProtocolStub.Response(
                    status: 429,
                    headers: ["Retry-After": "0"],
                    data: Data()
                )
            }
            return URLProtocolStub.Response(
                status: 200,
                data: #"{"id":"abc","threadId":"t1","snippet":"hello","payload":{"headers":[]}}"#.data(using: .utf8)!
            )
        }

        let message = try await sut.fetchMessage(id: "abc", format: .full)

        XCTAssertEqual(calls, 2)
        XCTAssertEqual(message.id, "abc")
    }

    func testRefreshOn401AndRetryOnce() async throws {
        var calls = 0
        URLProtocolStub.respond { request in
            calls += 1
            if calls == 1 {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
                return URLProtocolStub.Response(status: 401, data: Data())
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer refreshed-token")
            return URLProtocolStub.Response(
                status: 200,
                data: #"{"emailAddress":"a@b.com","historyId":"42"}"#.data(using: .utf8)!
            )
        }
        fakeAuth.nextRefreshedToken = "refreshed-token"

        let profile = try await sut.profile()

        XCTAssertEqual(calls, 2)
        XCTAssertEqual(profile.emailAddress, "a@b.com")
        XCTAssertEqual(fakeAuth.tokenCallCount, 2)
    }

    func testSecondConsecutive401ThrowsReauthRequired() async throws {
        URLProtocolStub.respond { _ in
            URLProtocolStub.Response(status: 401, data: Data())
        }
        fakeAuth.nextRefreshedToken = "still-bad-token"

        do {
            _ = try await sut.profile()
            XCTFail("Expected throw")
        } catch GoogleAuthError.reauthenticationRequired {
            // expected
        }
    }

    func testHistory404ThrowsHistoryExpired() async throws {
        URLProtocolStub.respond { _ in
            URLProtocolStub.Response(status: 404, data: Data())
        }

        do {
            _ = try await sut.history(startHistoryId: "old-cursor")
            XCTFail("Expected throw")
        } catch GmailClientError.historyExpired {
            // expected
        }
    }
}

// MARK: - Test doubles

@MainActor
final class RecordingAuthService: GoogleAuthService {
    var initialToken: String
    var nextRefreshedToken: String?
    private(set) var tokenCallCount = 0

    nonisolated init(token: String) {
        initialToken = token
    }

    func signIn(presenting _: UIViewController) async throws -> GoogleAccountInfo {
        fatalError("not used")
    }

    func signOut() async {}

    func currentAccount() -> GoogleAccountInfo? {
        GoogleAccountInfo(email: "a@b.com", accessToken: initialToken, refreshToken: "r", expiresAt: .distantFuture)
    }

    func accessToken() async throws -> String {
        tokenCallCount += 1
        if tokenCallCount > 1, let refreshed = nextRefreshedToken {
            initialToken = refreshed
        }
        return initialToken
    }
}

final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    struct Response {
        let status: Int
        var headers: [String: String] = [:]
        let data: Data
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var handler: ((URLRequest) -> Response)?

    static func respond(_ block: @escaping (URLRequest) -> Response) {
        lock.withLock { handler = block }
    }

    static func reset() {
        lock.withLock { handler = nil }
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let resp: Response = Self.lock.withLock {
            guard let h = Self.handler else {
                fatalError("URLProtocolStub.respond not configured")
            }
            return h(self.request)
        }
        let httpResp = HTTPURLResponse(
            url: request.url!,
            statusCode: resp.status,
            httpVersion: "HTTP/1.1",
            headerFields: resp.headers
        )!
        client?.urlProtocol(self, didReceive: httpResp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: resp.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
