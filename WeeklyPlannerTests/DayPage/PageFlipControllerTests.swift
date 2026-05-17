import XCTest
@testable import WeeklyPlanner

@MainActor
final class PageFlipControllerTests: XCTestCase {
    func testInitialStateNotFlipping() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 5))
        XCTAssertFalse(controller.isFlipping)
        XCTAssertNil(controller.target)
        XCTAssertNil(controller.direction)
    }

    func testFlipNextAdvancesDayWithinWeek() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 5))
        controller.flipDay(direction: .next)
        XCTAssertEqual(controller.target, PageCoordinate(week: 0, day: 6))
        XCTAssertEqual(controller.direction, .next)
    }

    func testFlipNextOnSundayCrossesIntoNextWeek() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 6))
        controller.flipDay(direction: .next)
        XCTAssertEqual(controller.target, PageCoordinate(week: 1, day: 0))
    }

    func testFlipPrevOnMondayCrossesIntoPreviousWeek() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 0))
        controller.flipDay(direction: .prev)
        XCTAssertEqual(controller.target, PageCoordinate(week: -1, day: 6))
    }

    func testFlipToDayInfersForwardDirectionWhenIdxLater() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 2))
        controller.flipToDay(idx: 5)
        XCTAssertEqual(controller.direction, .next)
        XCTAssertEqual(controller.target?.day, 5)
    }

    func testFlipToDayInfersBackwardDirectionWhenIdxEarlier() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 5))
        controller.flipToDay(idx: 1)
        XCTAssertEqual(controller.direction, .prev)
        XCTAssertEqual(controller.target?.day, 1)
    }

    func testFlipToDaySameIdxIsNoop() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 3))
        controller.flipToDay(idx: 3)
        XCTAssertNil(controller.target)
        XCTAssertFalse(controller.isFlipping)
    }

    func testFlipIgnoredWhileAnimating() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 0))
        controller.flipDay(direction: .next) // starts flip to (0, 1)
        controller.flipDay(direction: .next) // should be ignored
        XCTAssertEqual(controller.target, PageCoordinate(week: 0, day: 1))
    }

    func testCommitMovesCurrentToTargetAndClearsState() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 5))
        controller.flipDay(direction: .next)
        controller.commit()
        XCTAssertEqual(controller.current, PageCoordinate(week: 0, day: 6))
        XCTAssertNil(controller.target)
        XCTAssertNil(controller.direction)
        XCTAssertFalse(controller.isFlipping)
    }

    func testCommitWithoutTargetIsNoop() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 5))
        controller.commit()
        XCTAssertEqual(controller.current, PageCoordinate(week: 0, day: 5))
    }

    func testCancelClearsTargetAndDirection() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 5))
        controller.flipDay(direction: .next)
        controller.cancel()
        XCTAssertNil(controller.target)
        XCTAssertEqual(controller.current, PageCoordinate(week: 0, day: 5))
        XCTAssertFalse(controller.isFlipping)
    }
}
