import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventTemplateTests: XCTestCase {
    func testCuratedSetHasAtLeastSixUniqueTemplates() {
        XCTAssertGreaterThanOrEqual(EventTemplate.curated.count, 6)
        XCTAssertEqual(Set(EventTemplate.curated.map(\.id)).count, EventTemplate.curated.count)
    }

    func testApplyPrefillsComposerKeepingStartAnchor() throws {
        let anchor = Date(timeIntervalSince1970: 1_780_000_000)
        let state = EventComposerState.empty(at: anchor, calendar: WeekMath.mondayCalendar())
        let originalStart = state.start

        let gym = try XCTUnwrap(EventTemplate.curated.first { $0.id == "gym" })
        state.apply(gym)

        XCTAssertEqual(state.title, "Gym")
        XCTAssertEqual(state.category, .health)
        XCTAssertEqual(state.start, originalStart, "Template must not move the chosen start")
        XCTAssertEqual(state.end, originalStart.addingTimeInterval(60 * 60))
        XCTAssertTrue(state.alertOn)
        XCTAssertEqual(state.alertMinutes, 15)
    }

    func testApplyWithoutAlertTurnsAlertOff() throws {
        let state = EventComposerState.empty(at: Date(timeIntervalSince1970: 1_780_000_000),
                                             calendar: WeekMath.mondayCalendar())
        let lunch = try XCTUnwrap(EventTemplate.curated.first { $0.id == "lunch" })
        state.apply(lunch)

        XCTAssertEqual(state.title, "Lunch")
        XCTAssertFalse(state.alertOn)
    }

    func testApplyKeepsComposerSavable() {
        let state = EventComposerState.empty(at: Date(timeIntervalSince1970: 1_780_000_000),
                                             calendar: WeekMath.mondayCalendar())
        state.apply(EventTemplate.curated[0])
        XCTAssertTrue(state.canSave)
    }
}
