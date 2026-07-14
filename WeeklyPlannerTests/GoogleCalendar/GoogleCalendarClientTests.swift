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

    func testCreateEventPostsJSONAndReturnsId() async throws {
        URLProtocolStub.respond { req in
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.url?.path, "/calendar/v3/calendars/primary/events")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
            return .init(status: 200, data: #"""
            {"id":"new1","status":"confirmed","summary":"Lunch",
             "start":{"dateTime":"2026-07-09T12:00:00Z"},
             "end":{"dateTime":"2026-07-09T13:00:00Z"},
             "etag":"\"e1\"","updated":"2026-07-09T12:00:00Z"}
            """#.data(using: .utf8)!)
        }
        let body = makeWriteBody(summary: "Lunch")

        let created = try await sut.createEvent(body)

        XCTAssertEqual(created.id, "new1")
        XCTAssertEqual(created.etag, "\"e1\"")
    }

    func testUpdateEventSendsIfMatch() async throws {
        URLProtocolStub.respond { req in
            XCTAssertEqual(req.httpMethod, "PUT")
            XCTAssertTrue(req.url?.path.hasSuffix("/events/gid1") == true)
            XCTAssertEqual(req.value(forHTTPHeaderField: "If-Match"), "\"old\"")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
            return .init(status: 200, data: #"""
            {"id":"gid1","status":"confirmed","summary":"Updated",
             "start":{"dateTime":"2026-07-09T12:00:00Z"},
             "end":{"dateTime":"2026-07-09T13:00:00Z"},
             "etag":"\"new\"","updated":"2026-07-09T13:00:00Z"}
            """#.data(using: .utf8)!)
        }
        let body = makeWriteBody(summary: "Updated")

        let updated = try await sut.updateEvent(id: "gid1", body: body, etag: "\"old\"")

        XCTAssertEqual(updated.etag, "\"new\"")
    }

    func testUpdateEvent412ThrowsPreconditionFailed() async throws {
        URLProtocolStub.respond { req in
            XCTAssertEqual(req.httpMethod, "PUT")
            return .init(status: 412, data: Data())
        }
        let body = makeWriteBody(summary: "Stale")

        do {
            _ = try await sut.updateEvent(id: "gid1", body: body, etag: "\"stale\"")
            XCTFail("expected throw")
        } catch GoogleCalendarClientError.preconditionFailed {
            /* expected */
        }
    }

    func testCancelEventPatchesCancelled() async throws {
        URLProtocolStub.respond { req in
            XCTAssertEqual(req.httpMethod, "PATCH")
            XCTAssertTrue(req.url?.path.hasSuffix("/events/gid1") == true)
            XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
            return .init(status: 200, data: #"""
            {"id":"gid1","status":"cancelled",
             "start":{"dateTime":"2026-07-09T12:00:00Z"},
             "end":{"dateTime":"2026-07-09T13:00:00Z"}}
            """#.data(using: .utf8)!)
        }

        try await sut.cancelEvent(id: "gid1")
    }

    func testCancelEvent404ThrowsNotFound() async throws {
        URLProtocolStub.respond { req in
            XCTAssertEqual(req.httpMethod, "PATCH")
            return .init(status: 404, data: Data())
        }

        do {
            try await sut.cancelEvent(id: "missing")
            XCTFail("expected throw")
        } catch GoogleCalendarClientError.notFound {
            /* expected */
        }
    }

    func testGetEventFetchesById() async throws {
        URLProtocolStub.respond { req in
            XCTAssertEqual(req.httpMethod, "GET")
            XCTAssertTrue(req.url?.path.hasSuffix("/events/gid1") == true)
            return .init(status: 200, data: #"""
            {"id":"gid1","status":"confirmed","summary":"Hi",
             "start":{"dateTime":"2026-07-09T12:00:00Z"},
             "end":{"dateTime":"2026-07-09T13:00:00Z"},
             "etag":"\"e\"","updated":"2026-07-09T11:00:00Z"}
            """#.data(using: .utf8)!)
        }

        let event = try await sut.getEvent(id: "gid1")

        XCTAssertEqual(event.id, "gid1")
        XCTAssertEqual(event.summary, "Hi")
    }

    private func makeWriteBody(summary: String) -> GCalEventWriteBody {
        GCalEventWriteBody(
            summary: summary,
            location: nil,
            description: nil,
            start: GCalDateTime(date: nil, dateTime: "2026-07-09T12:00:00Z"),
            end: GCalDateTime(date: nil, dateTime: "2026-07-09T13:00:00Z")
        )
    }
}
