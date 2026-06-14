import XCTest
@testable import WeeklyPlanner

final class GCalMapperTests: XCTestCase {
    private func gcal(_ id: String, status: String? = "confirmed",
                      startDT: String? = nil, endDT: String? = nil,
                      startDate: String? = nil, endDate: String? = nil,
                      summary: String? = "Title", location: String? = nil) -> GCalEvent {
        GCalEvent(id: id, status: status, summary: summary, location: location, description: nil,
                  start: .init(date: startDate, dateTime: startDT),
                  end: .init(date: endDate, dateTime: endDT),
                  etag: nil, updated: nil)
    }

    func testTimedEventMaps() throws {
        let e = try XCTUnwrap(GCalMapper.event(from:
            gcal("e1", startDT: "2026-06-14T12:00:00Z", endDT: "2026-06-14T13:00:00Z", location: "Cafe")))
        XCTAssertEqual(e.title, "Title")
        XCTAssertEqual(e.location, "Cafe")
        XCTAssertEqual(e.source, .googleCalendar)
        XCTAssertEqual(e.googleEventID, "e1")
        XCTAssertEqual(e.end.timeIntervalSince(e.start), 3600, accuracy: 1)
    }

    func testAllDayEventMaps() throws {
        let e = try XCTUnwrap(GCalMapper.event(from:
            gcal("e2", startDate: "2026-06-20", endDate: "2026-06-21")))
        XCTAssertEqual(e.googleEventID, "e2")
        XCTAssertTrue(e.end > e.start)
    }

    func testDeterministicIdIsStableAndDistinct() throws {
        let a1 = GCalMapper.deterministicID(for: "e1")
        let a2 = GCalMapper.deterministicID(for: "e1")
        let b = GCalMapper.deterministicID(for: "e2")
        XCTAssertEqual(a1, a2)
        XCTAssertNotEqual(a1, b)
    }

    func testCancelledMapsToNil() {
        XCTAssertNil(GCalMapper.event(from: gcal("e3", status: "cancelled",
                                                 startDate: "2026-06-20", endDate: "2026-06-21")))
    }

    func testMissingTitleGetsPlaceholder() throws {
        let e = try XCTUnwrap(GCalMapper.event(from:
            gcal("e4", startDT: "2026-06-14T12:00:00Z", endDT: "2026-06-14T13:00:00Z", summary: nil)))
        XCTAssertFalse(e.title.isEmpty)
    }
}
