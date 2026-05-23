import Foundation
import XCTest
@testable import WeeklyPlanner

@MainActor
final class TaskComposerStateTests: XCTestCase {
    func testDefaults() {
        let day = Date(timeIntervalSince1970: 1_780_000_000)
        let state = TaskComposerState(forDay: day)
        XCTAssertEqual(state.title, "")
        XCTAssertFalse(state.isComposing)
        XCTAssertEqual(state.priority, .med)
        XCTAssertEqual(state.due, day)
        XCTAssertFalse(state.canCommit)
    }

    func testCanCommit_falseWhenTitleEmptyOrWhitespace() {
        let state = TaskComposerState(forDay: Date())
        XCTAssertFalse(state.canCommit)
        state.title = "   "
        XCTAssertFalse(state.canCommit)
        state.title = "Prep slides"
        XCTAssertTrue(state.canCommit)
    }

    func testBuild_usesDayAndCurrentPriority_trimsTitle() {
        let day = Date(timeIntervalSince1970: 1_780_000_000)
        let state = TaskComposerState(forDay: day)
        state.title = "  Prep slides  "
        state.priority = .high
        let task = state.build(category: .work)
        XCTAssertEqual(task.title, "Prep slides")
        XCTAssertEqual(task.priority, .high)
        XCTAssertEqual(task.due, day)
        XCTAssertEqual(task.category, .work)
        XCTAssertFalse(task.done)
    }

    func testReset_clearsTitleKeepsComposing() {
        let state = TaskComposerState(forDay: Date())
        state.isComposing = true
        state.title = "Prep slides"
        state.reset()
        XCTAssertEqual(state.title, "")
        XCTAssertTrue(state.isComposing, "reset should keep composing so user can chain adds")
    }

    func testExit_clearsAndStopsComposing() {
        let state = TaskComposerState(forDay: Date())
        state.isComposing = true
        state.title = "Prep slides"
        state.priority = .high
        state.exit()
        XCTAssertEqual(state.title, "")
        XCTAssertFalse(state.isComposing)
        XCTAssertEqual(state.priority, .med, "exit should reset priority to the default")
    }

    func testSetDay_updatesDueDate() {
        let firstDay = Date(timeIntervalSince1970: 1_780_000_000)
        let nextDay = firstDay.addingTimeInterval(86_400)
        let state = TaskComposerState(forDay: firstDay)
        state.setDay(nextDay)
        XCTAssertEqual(state.due, nextDay)
    }
}
