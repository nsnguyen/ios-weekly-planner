import XCTest
@testable import WeeklyPlanner

final class WeekdayIndexTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) throws -> Date {
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        components.hour = 12
        return try XCTUnwrap(WeekMath.mondayCalendar().date(from: components))
    }

    func testEventWeekdayIndexFollowsCalendarFirstWeekday() throws {
        // Sun May 10 2026 / Mon May 11 2026.
        let sundayEvent = try Event(title: "Sun", start: date(2026, 5, 10),
                                    end: date(2026, 5, 10).addingTimeInterval(3600), category: .personal)
        let mondayEvent = try Event(title: "Mon", start: date(2026, 5, 11),
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

    func testTaskWeekOffsetRespectsWeekBoundary() throws {
        // Base Sat May 16 2026. Due Sun May 17:
        //   Monday-start  → same week (offset 0)
        //   Sunday-start  → next week (offset 1)
        let task = try TaskItem(title: "t", due: date(2026, 5, 17), category: .personal)

        XCTAssertEqual(try task.weekOffset(from: date(2026, 5, 16), calendar: WeekMath.mondayCalendar()), 0)
        XCTAssertEqual(try task.weekOffset(from: date(2026, 5, 16), calendar: WeekMath.sundayCalendar()), 1)
    }
}
