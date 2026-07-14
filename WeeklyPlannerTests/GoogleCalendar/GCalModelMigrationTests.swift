import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class GCalModelMigrationTests: XCTestCase {
    func testEventHasNilGoogleEventIDByDefault() {
        let e = Event(title: "x", start: .now, end: .now, category: .personal)
        XCTAssertNil(e.googleEventID)
    }

    func testEventStoresGoogleEventID() {
        let e = Event(title: "x", start: .now, end: .now, category: .personal,
                      source: .googleCalendar, googleEventID: "gid_123")
        XCTAssertEqual(e.googleEventID, "gid_123")
        XCTAssertEqual(e.source, .googleCalendar)
    }

    func testEventHasNilGoogleEtagByDefault() {
        let e = Event(title: "x", start: .now, end: .now, category: .personal)
        XCTAssertNil(e.googleEtag)
    }

    func testEventStoresGoogleEtag() {
        let e = Event(title: "x", start: .now, end: .now, category: .personal,
                      googleEventID: "gid", googleEtag: "\"etag1\"")
        XCTAssertEqual(e.googleEtag, "\"etag1\"")
    }

    func testOccurrenceCopyCarriesGoogleEtag() {
        let e = Event(title: "x", start: .now, end: .now.addingTimeInterval(3600),
                      category: .personal, googleEventID: "gid", googleEtag: "\"e\"")
        let copy = e.occurrenceCopy(start: e.start.addingTimeInterval(86400))
        XCTAssertEqual(copy.googleEtag, "\"e\"")
        XCTAssertEqual(copy.googleEventID, "gid")
    }

    func testUserSettingsGcalSyncTokenDefaultsNil() {
        let s = UserSettings()
        XCTAssertNil(s.gcalSyncToken)
        XCTAssertNil(s.googleCalendarAccountEmail)
    }
}
