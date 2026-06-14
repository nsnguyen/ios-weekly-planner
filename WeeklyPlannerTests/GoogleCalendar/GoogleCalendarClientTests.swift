import XCTest
@testable import WeeklyPlanner

@MainActor
final class GoogleCalendarClientTests: XCTestCase {
    private var fakeAuth: RecordingAuthService!
    private var session: URLSession!
    private var sut: GoogleCalendarClient!

    override func setUp() async throws {
        try await super.setUp()
        fakeAuth = RecordingAuthService(token: "test-token")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        session = URLSession(configuration: config)
        URLProtocolStub.reset()
        sut = GoogleCalendarClient(auth: fakeAuth, session: session)
    }
    override func tearDown() async throws { URLProtocolStub.reset(); try await super.tearDown() }

    func testListEventsSendsSingleEventsAndBearer() async throws {
        URLProtocolStub.respond { req in
            XCTAssertEqual(req.url?.path, "/calendar/v3/calendars/primary/events")
            XCTAssertEqual(req.url?.query?.contains("singleEvents=true"), true)
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            return .init(status: 200, data: #"{"items":[{"id":"e1","start":{"dateTime":"2026-06-14T12:00:00Z"},"end":{"dateTime":"2026-06-14T13:00:00Z"}}],"nextSyncToken":"TOK"}"#.data(using: .utf8)!)
        }
        let page = try await sut.listEvents(syncToken: nil, timeMin: .now, timeMax: .now, pageToken: nil)
        XCTAssertEqual(page.items.first?.id, "e1")
        XCTAssertEqual(page.nextSyncToken, "TOK")
    }

    func testListEventsSendsSyncTokenWhenPresent() async throws {
        URLProtocolStub.respond { req in
            XCTAssertEqual(req.url?.query?.contains("syncToken=PREV"), true)
            return .init(status: 200, data: #"{"items":[],"nextSyncToken":"NEXT"}"#.data(using: .utf8)!)
        }
        _ = try await sut.listEvents(syncToken: "PREV", timeMin: nil, timeMax: nil, pageToken: nil)
    }

    func testRetriesOn429() async throws {
        var calls = 0
        URLProtocolStub.respond { _ in
            calls += 1
            return calls == 1
                ? .init(status: 429, headers: ["Retry-After": "0"], data: Data())
                : .init(status: 200, data: #"{"items":[]}"#.data(using: .utf8)!)
        }
        _ = try await sut.listEvents(syncToken: nil, timeMin: nil, timeMax: nil, pageToken: nil)
        XCTAssertEqual(calls, 2)
    }

    func testRefreshOn401() async throws {
        var calls = 0
        URLProtocolStub.respond { req in
            calls += 1
            if calls == 1 { return .init(status: 401, data: Data()) }
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer refreshed-token")
            return .init(status: 200, data: #"{"items":[]}"#.data(using: .utf8)!)
        }
        fakeAuth.nextRefreshedToken = "refreshed-token"
        _ = try await sut.listEvents(syncToken: nil, timeMin: nil, timeMax: nil, pageToken: nil)
        XCTAssertEqual(calls, 2)
    }

    func test410ThrowsSyncTokenExpired() async throws {
        URLProtocolStub.respond { _ in .init(status: 410, data: Data()) }
        do {
            _ = try await sut.listEvents(syncToken: "old", timeMin: nil, timeMax: nil, pageToken: nil)
            XCTFail("expected throw")
        } catch GoogleCalendarClientError.syncTokenExpired { /* expected */ }
    }
}
