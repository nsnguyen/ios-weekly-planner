import Foundation
import XCTest
@testable import WeeklyPlanner

final class WeekMathTests: XCTestCase {
    /// Reference date used throughout the mock: Saturday, May 16, 2026.
    private static func may16_2026() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = 12
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }

    func testWeekDaysOffsetZeroOnMay16_2026ReturnsMay11ThroughMay17() {
        let week = WeekMath.weekDays(forOffset: 0, today: Self.may16_2026())
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first?.dayNumber, 11)
        XCTAssertEqual(week.first?.weekdayShort, "Mon")
        XCTAssertEqual(week.last?.dayNumber, 17)
        XCTAssertEqual(week.last?.weekdayShort, "Sun")
        XCTAssertEqual(week.first?.monthShort, "May")
    }

    func testWeekDaysOffsetMinusOneReturnsMay4ThroughMay10() {
        let week = WeekMath.weekDays(forOffset: -1, today: Self.may16_2026())
        XCTAssertEqual(week.first?.dayNumber, 4)
        XCTAssertEqual(week.last?.dayNumber, 10)
        XCTAssertEqual(week.first?.weekdayShort, "Mon")
    }

    func testWeekMetaRangeSameMonth() {
        let meta = WeekMath.weekMeta(forOffset: 0, today: Self.may16_2026())
        XCTAssertEqual(meta.range, "May 11 – 17")
        XCTAssertTrue(meta.isCurrent)
    }

    func testWeekMetaRangeCrossMonth() throws {
        // The week containing May 30, 2026 spans into June.
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 30
        components.hour = 12
        let may30 = try XCTUnwrap(WeekMath.mondayCalendar().date(from: components))
        let meta = WeekMath.weekMeta(forOffset: 0, today: may30)
        // Monday of that week is May 25; Sunday is May 31. So same-month for that week.
        // To force cross-month, look at offset +1 (June 1-7) — but that's the easy case.
        // Better: a week that genuinely crosses, e.g., May 30 sits in week of May 25-31.
        // The cross-month week is May 27-Jun 2 if Wed-start, but we're Monday-start.
        // Actual cross-month week for May 2026: week of June 29 - July 5. Pick that.
        var late = DateComponents()
        late.year = 2026
        late.month = 6
        late.day = 30
        late.hour = 12
        let june30 = try XCTUnwrap(WeekMath.mondayCalendar().date(from: late))
        let crossMeta = WeekMath.weekMeta(forOffset: 0, today: june30)
        XCTAssertTrue(crossMeta.range.contains("–"))
        // The week of June 29 - July 5 should render as "Jun 29 – Jul 5".
        XCTAssertEqual(crossMeta.range, "Jun 29 – Jul 5")

        _ = meta // silence unused
    }

    func testTodayIndexInCurrentWeekIs5OnMay16_2026() {
        let today = Self.may16_2026()
        let week = WeekMath.weekDays(forOffset: 0, today: today)
        XCTAssertEqual(WeekMath.todayIndex(in: week, for: today), 5)
    }

    func testWeekdayInitialsAreSingleLetters() {
        let week = WeekMath.weekDays(forOffset: 0, today: Self.may16_2026())
        XCTAssertEqual(week.map(\.weekdayInitial), ["M", "T", "W", "T", "F", "S", "S"])
    }
}
