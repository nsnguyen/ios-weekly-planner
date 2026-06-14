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

    func testUserSettingsGcalSyncTokenDefaultsNil() {
        let s = UserSettings()
        XCTAssertNil(s.gcalSyncToken)
        XCTAssertNil(s.googleCalendarAccountEmail)
    }
}
