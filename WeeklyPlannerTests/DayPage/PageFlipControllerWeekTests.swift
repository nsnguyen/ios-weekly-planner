import XCTest
@testable import WeeklyPlanner

/// Coverage for the week-granularity controller methods added in Phase 09
/// Group Q: `flipWeek(direction:)` (animated whole-week step) and
/// `setWeek(_:)` (instant whole-week jump). The day-granularity behavior is
/// covered by `PageFlipControllerTests`.
@MainActor
final class PageFlipControllerWeekTests: XCTestCase {
    func testFlipWeekNextAdvancesWeek() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 5))
        controller.flipWeek(direction: .next)
        XCTAssertEqual(controller.target, PageCoordinate(week: 1, day: 5))
        XCTAssertEqual(controller.direction, .next)
        XCTAssertTrue(controller.isFlipping)
    }

    func testFlipWeekPrevDecreasesWeek() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 5))
        controller.flipWeek(direction: .prev)
        XCTAssertEqual(controller.target, PageCoordinate(week: -1, day: 5))
        XCTAssertEqual(controller.direction, .prev)
        XCTAssertTrue(controller.isFlipping)
    }

    func testSetWeekInstantlyChangesCurrentNoTarget() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 5))
        controller.setWeek(3)
        XCTAssertEqual(controller.current, PageCoordinate(week: 3, day: 5))
        XCTAssertNil(controller.target)
        XCTAssertNil(controller.direction)
        XCTAssertFalse(controller.isFlipping)
    }
}
