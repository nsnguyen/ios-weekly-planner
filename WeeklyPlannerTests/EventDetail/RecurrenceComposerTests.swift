import XCTest
@testable import WeeklyPlanner

@MainActor
final class RecurrenceComposerTests: XCTestCase {
    private func makeEvent(recurrence: Recurrence?) -> Event {
        Event(title: "Gym",
              start: Date(timeIntervalSince1970: 1_780_000_000),
              end: Date(timeIntervalSince1970: 1_780_003_600),
              category: .health,
              recurrence: recurrence)
    }

    func testFromEventCarriesRecurrenceAndBuildRoundTrips() {
        let recurrence = Recurrence(frequency: .weekly, interval: 2, end: .afterCount(6))
        let state = EventComposerState.from(makeEvent(recurrence: recurrence))
        XCTAssertEqual(state.recurrence, recurrence)

        let rebuilt = state.build()
        XCTAssertEqual(rebuilt.recurrence, recurrence)
        XCTAssertTrue(rebuilt.isRecurring)
    }

    func testEmptyComposerHasNoRecurrence() {
        let state = EventComposerState.empty(at: Date(timeIntervalSince1970: 1_780_000_000),
                                             calendar: WeekMath.mondayCalendar())
        XCTAssertNil(state.recurrence)
        XCTAssertNil(state.build().recurrence)
        XCTAssertFalse(state.build().isRecurring)
    }

    func testIsDirtyDetectsRecurrenceChange() {
        let baseline = EventComposerState.from(makeEvent(recurrence: nil))
        let edited = EventComposerState.from(makeEvent(recurrence: nil))
        XCTAssertFalse(edited.isDirty(against: baseline))

        edited.recurrence = Recurrence(frequency: .daily)
        XCTAssertTrue(edited.isDirty(against: baseline))
    }
}
