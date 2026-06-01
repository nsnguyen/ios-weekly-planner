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

    // MARK: - Phase 27: no-strand invariants (the Week-view freeze fix)

    /// After an explicit `commit()` the controller is fully idle.
    func testFlipThenCommitClearsTarget() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 2))
        controller.flipDay(direction: .next)
        controller.commit()
        XCTAssertFalse(controller.isFlipping)
        XCTAssertNil(controller.target)
        XCTAssertNil(controller.direction)
    }

    /// Cancelling an in-flight flip resets state without moving `current`.
    func testInterruptedFlipCancels() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 2))
        controller.flipDay(direction: .next)
        controller.cancel()
        XCTAssertNil(controller.target)
        XCTAssertNil(controller.direction)
        XCTAssertEqual(controller.current, PageCoordinate(week: 0, day: 2))
        XCTAssertFalse(controller.isFlipping)
    }

    /// `setWeek` applies the new offset and keeps the day index.
    func testSetWeekAppliesOffset() {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 4))
        controller.setWeek(3)
        XCTAssertEqual(controller.current, PageCoordinate(week: 3, day: 4))
        XCTAssertFalse(controller.isFlipping)
    }

    /// The core regression test for the freeze: a flip with **no** view layer
    /// to drive `commit()` (exactly the old Week-view `flipWeek` situation)
    /// must still resolve on its own via the controller's fallback, leaving
    /// the controller idle and navigable — never stranded with `isFlipping`.
    func testAutoCommitResolvesStrandedFlip() async {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 3),
                                            autoCommitDelay: .milliseconds(1))
        controller.flipWeek(direction: .next)
        XCTAssertTrue(controller.isFlipping)

        try? await Task.sleep(for: .milliseconds(60))

        XCTAssertFalse(controller.isFlipping, "flip must not strand isFlipping")
        XCTAssertEqual(controller.current, PageCoordinate(week: 1, day: 3))
    }

    /// A run of flips (each allowed to auto-resolve) all land and leave the
    /// controller idle — no flip ever gets stuck blocking the next.
    func testRapidFlipsNeverStrandIsFlipping() async {
        let controller = PageFlipController(current: PageCoordinate(week: 0, day: 0),
                                            autoCommitDelay: .milliseconds(1))
        for _ in 0..<5 {
            controller.flipDay(direction: .next)
            try? await Task.sleep(for: .milliseconds(25))
        }
        XCTAssertFalse(controller.isFlipping)
        XCTAssertEqual(controller.current, PageCoordinate(week: 0, day: 5))
    }
}
