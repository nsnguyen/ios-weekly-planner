import XCTest
@testable import WeeklyPlanner

final class GCalEventDecodingTests: XCTestCase {
    func testDecodesTimedEvent() throws {
        let json = #"""
        {"items":[{"id":"e1","status":"confirmed","summary":"Lunch",
          "location":"Cafe","description":"notes",
          "start":{"dateTime":"2026-06-14T12:00:00-07:00"},
          "end":{"dateTime":"2026-06-14T13:00:00-07:00"},
          "etag":"\"123\"","updated":"2026-06-14T00:00:00Z"}],
          "nextSyncToken":"TOK"}
        """#.data(using: .utf8)!
        let resp = try JSONDecoder().decode(GCalEventsListResponse.self, from: json)
        XCTAssertEqual(resp.nextSyncToken, "TOK")
        XCTAssertEqual(resp.items.first?.id, "e1")
        XCTAssertEqual(resp.items.first?.summary, "Lunch")
        XCTAssertNotNil(resp.items.first?.start.dateTime)
        XCTAssertNil(resp.items.first?.start.date)
    }

    func testDecodesIncrementalResponseWithNoItemsKey() throws {
        // Google omits `items` on a no-change incremental sync.
        let json = #"{"nextSyncToken":"TOK"}"#.data(using: .utf8)!
        let resp = try JSONDecoder().decode(GCalEventsListResponse.self, from: json)
        XCTAssertEqual(resp.items.count, 0)
        XCTAssertEqual(resp.nextSyncToken, "TOK")
    }

    func testDecodesAllDayAndCancelled() throws {
        let json = #"""
        {"items":[{"id":"e2","status":"cancelled","start":{"date":"2026-06-20"},
          "end":{"date":"2026-06-21"}}],"nextPageToken":"P2"}
        """#.data(using: .utf8)!
        let resp = try JSONDecoder().decode(GCalEventsListResponse.self, from: json)
        XCTAssertEqual(resp.nextPageToken, "P2")
        XCTAssertEqual(resp.items.first?.status, "cancelled")
        XCTAssertEqual(resp.items.first?.start.date, "2026-06-20")
    }
}
