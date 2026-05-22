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

    // MARK: - from(_:) coverage

    func testFromEvent_noReminders_alertOffDefaultMinutes() {
        let event = Event(title: "T",
                          start: Date(),
                          end: Date().addingTimeInterval(3600),
                          category: .personal)
        let state = EventComposerState.from(event)
        XCTAssertFalse(state.alertOn)
        XCTAssertEqual(state.alertMinutes, 15)
        XCTAssertFalse(state.locationAlertOn)
    }

    func testFromEvent_multipleTimeBefore_capturesFirstPreservesRest() {
        let event = Event(title: "T",
                          start: Date(),
                          end: Date().addingTimeInterval(3600),
                          category: .personal,
                          reminders: [.timeBefore(minutes: 10), .timeBefore(minutes: 30)])
        let state = EventComposerState.from(event)
        XCTAssertTrue(state.alertOn)
        XCTAssertEqual(state.alertMinutes, 10)
        // Round-trip via build() should re-emit both.
        let rebuilt = state.build(id: event.id)
        let minutes = rebuilt.reminders.compactMap { r -> Int? in
            if case let .timeBefore(m) = r { return m } else { return nil }
        }.sorted()
        XCTAssertEqual(minutes, [10, 30])
    }

    func testFromEvent_onArriveOnly_locationAlertOnAlertOff() {
        let geofence = LocationReminder(name: "HQ",
                                         latitude: 37.78,
                                         longitude: -122.41,
                                         radiusMeters: 100)
        let event = Event(title: "T",
                          start: Date(),
                          end: Date().addingTimeInterval(3600),
                          category: .personal,
                          reminders: [.onArrive(geofence)])
        let state = EventComposerState.from(event)
        XCTAssertFalse(state.alertOn)
        XCTAssertTrue(state.locationAlertOn)
        // Build should preserve the geofence verbatim.
        let rebuilt = state.build(id: event.id)
        let preservedGeofence = rebuilt.reminders.first { r in
            if case .onArrive = r { return true } else { return false }
        }
        XCTAssertNotNil(preservedGeofence)
    }

    func testBuild_locationAlertOff_dropsPreservedOnArrive() {
        let geofence = LocationReminder(name: "HQ",
                                         latitude: 37.78,
                                         longitude: -122.41,
                                         radiusMeters: 100)
        let event = Event(title: "T",
                          start: Date(),
                          end: Date().addingTimeInterval(3600),
                          category: .personal,
                          reminders: [.onArrive(geofence)])
        let state = EventComposerState.from(event)
        state.locationAlertOn = false
        let rebuilt = state.build(id: event.id)
        let hasOnArrive = rebuilt.reminders.contains { r in
            if case .onArrive = r { return true } else { return false }
        }
        XCTAssertFalse(hasOnArrive)
    }

    func testBuild_alertOff_omitsTimeBefore() {
        let state = EventComposerState.empty(at: Date(), calendar: .current)
        state.title = "Lunch"
        state.alertOn = false
        let event = state.build()
        XCTAssertTrue(event.reminders.isEmpty)
    }

    func testBuild_alertOn_emitsTimeBefore() {
        let state = EventComposerState.empty(at: Date(), calendar: .current)
        state.title = "Lunch"
        state.alertOn = true
        state.alertMinutes = 20
        let event = state.build()
        let minutes = event.reminders.compactMap { r -> Int? in
            if case let .timeBefore(m) = r { return m } else { return nil }
        }
        XCTAssertEqual(minutes, [20])
    }

    func testIsDirty_detectsEveryEditableField() {
        let baseline = EventComposerState.empty(at: Date(timeIntervalSince1970: 1_780_000_000),
                                                 calendar: .current)
        baseline.title = "Lunch"

        func freshCopy() -> EventComposerState {
            let s = EventComposerState.empty(at: baseline.start, calendar: .current)
            s.title = baseline.title
            s.start = baseline.start
            s.end = baseline.end
            s.category = baseline.category
            s.location = baseline.location
            s.alertOn = baseline.alertOn
            s.alertMinutes = baseline.alertMinutes
            s.locationAlertOn = baseline.locationAlertOn
            return s
        }

        XCTAssertFalse(freshCopy().isDirty(against: baseline))

        let titleMut = freshCopy(); titleMut.title = "Dinner"
        XCTAssertTrue(titleMut.isDirty(against: baseline))

        let startMut = freshCopy(); startMut.start = baseline.start.addingTimeInterval(60)
        XCTAssertTrue(startMut.isDirty(against: baseline))

        let endMut = freshCopy(); endMut.end = baseline.end.addingTimeInterval(60)
        XCTAssertTrue(endMut.isDirty(against: baseline))

        let catMut = freshCopy(); catMut.category = .work
        XCTAssertTrue(catMut.isDirty(against: baseline))

        let locMut = freshCopy(); locMut.location = "HQ"
        XCTAssertTrue(locMut.isDirty(against: baseline))

        let alertMut = freshCopy(); alertMut.alertOn = true
        XCTAssertTrue(alertMut.isDirty(against: baseline))

        let minMut = freshCopy(); minMut.alertMinutes = 30
        XCTAssertTrue(minMut.isDirty(against: baseline))

        let geoMut = freshCopy(); geoMut.locationAlertOn = true
        XCTAssertTrue(geoMut.isDirty(against: baseline))
    }
}
