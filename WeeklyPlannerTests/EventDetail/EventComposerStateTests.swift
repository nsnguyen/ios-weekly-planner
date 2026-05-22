import Foundation
import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventComposerStateTests: XCTestCase {
    func testEmptyDefaults_startNextHour_endPlusOne() {
        let now = Date(timeIntervalSince1970: 1_780_000_000) // 2026-06-04 19:13:20 UTC
        let calendar = WeekMath.mondayCalendar()
        let state = EventComposerState.empty(at: now, calendar: calendar)

        XCTAssertEqual(state.title, "")
        XCTAssertEqual(state.category, .personal)
        XCTAssertTrue(state.end > state.start)
        XCTAssertEqual(state.end.timeIntervalSince(state.start), 3600, accuracy: 0.5)

        // start should be the next hour boundary after `now`.
        let components = calendar.dateComponents([.minute, .second], from: state.start)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    func testFromEvent_roundTrips() {
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        let end = start.addingTimeInterval(7200)
        let event = Event(title: "Standup",
                          start: start,
                          end: end,
                          location: "HQ",
                          category: .work,
                          reminders: [.timeBefore(minutes: 30)])
        let state = EventComposerState.from(event)
        XCTAssertEqual(state.title, "Standup")
        XCTAssertEqual(state.start, start)
        XCTAssertEqual(state.end, end)
        XCTAssertEqual(state.location, "HQ")
        XCTAssertEqual(state.category, .work)
        XCTAssertTrue(state.alertOn)
        XCTAssertEqual(state.alertMinutes, 30)
    }

    func testCanSave_falseWhenTitleEmpty() {
        let state = EventComposerState.empty(at: Date(), calendar: .current)
        XCTAssertFalse(state.canSave)
        state.title = "   "
        XCTAssertFalse(state.canSave)
        state.title = "Lunch"
        XCTAssertTrue(state.canSave)
    }

    func testCanSave_falseWhenEndBeforeStart() {
        let state = EventComposerState.empty(at: Date(), calendar: .current)
        state.title = "Lunch"
        state.end = state.start.addingTimeInterval(-60)
        XCTAssertFalse(state.canSave)
    }

    func testBuild_setsSourceManual() {
        let state = EventComposerState.empty(at: Date(), calendar: .current)
        state.title = "Lunch"
        let event = state.build()
        XCTAssertEqual(event.title, "Lunch")
        XCTAssertEqual(event.source, .manual)
        XCTAssertEqual(event.attendeesCount, 0)
        XCTAssertNil(event.location)
    }

    func testBuild_preservesProvidedID() {
        let state = EventComposerState.empty(at: Date(), calendar: .current)
        state.title = "Lunch"
        let id = UUID()
        let event = state.build(id: id)
        XCTAssertEqual(event.id, id)
    }

    func testIsDirty_detectsTitleChange() {
        let baseline = EventComposerState.empty(at: Date(), calendar: .current)
        baseline.title = "Lunch"
        let current = EventComposerState.empty(at: Date(), calendar: .current)
        current.title = "Lunch"
        current.start = baseline.start
        current.end = baseline.end
        XCTAssertFalse(current.isDirty(against: baseline))
        current.title = "Dinner"
        XCTAssertTrue(current.isDirty(against: baseline))
    }
}
