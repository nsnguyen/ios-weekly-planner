import XCTest
@testable import WeeklyPlanner

final class WeekdayIndexTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        return WeekMath.mondayCalendar().date(from: c)!
    }

    func testEventWeekdayIndexFollowsCalendarFirstWeekday() {
        // Sun May 10 2026 / Mon May 11 2026.
        let sundayEvent = Event(title: "Sun", start: date(2026, 5, 10),
                                end: date(2026, 5, 10).addingTimeInterval(3600), category: .personal)
        let mondayEvent = Event(title: "Mon", start: date(2026, 5, 11),
                                end: date(2026, 5, 11).addingTimeInterval(3600), category: .personal)

        let monCal = WeekMath.mondayCalendar()
        XCTAssertEqual(sundayEvent.weekdayIndex(in: monCal), 6)
        XCTAssertEqual(mondayEvent.weekdayIndex(in: monCal), 0)

        let sunCal = WeekMath.sundayCalendar()
        XCTAssertEqual(sundayEvent.weekdayIndex(in: sunCal), 0)
        XCTAssertEqual(mondayEvent.weekdayIndex(in: sunCal), 1)

        let satCal = WeekMath.calendar(startingOn: .saturday)
        XCTAssertEqual(sundayEvent.weekdayIndex(in: satCal), 1)
        XCTAssertEqual(mondayEvent.weekdayIndex(in: satCal), 2)
    }

    func testTaskWeekOffsetRespectsWeekBoundary() {
        // Base Sat May 16 2026. Due Sun May 17:
        //   Monday-start  → same week (offset 0)
        //   Sunday-start  → next week (offset 1)
        let task = TaskItem(title: "t", due: date(2026, 5, 17), category: .personal)

        XCTAssertEqual(task.weekOffset(from: date(2026, 5, 16), calendar: WeekMath.mondayCalendar()), 0)
        XCTAssertEqual(task.weekOffset(from: date(2026, 5, 16), calendar: WeekMath.sundayCalendar()), 1)
    }
}
