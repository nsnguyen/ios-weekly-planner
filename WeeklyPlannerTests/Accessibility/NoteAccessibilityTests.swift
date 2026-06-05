import XCTest
@testable import WeeklyPlanner

final class NoteAccessibilityTests: XCTestCase {
    func testNoteLabelIncludesTitleAndKind() {
        let goal = Note(title: "Marathon", body: "x", kind: .goal)
        XCTAssertEqual(AccessibilityFormatters.noteLabel(goal), "Marathon, goal")

        let misc = Note(title: "Groceries", body: "x", kind: .misc)
        XCTAssertEqual(AccessibilityFormatters.noteLabel(misc), "Groceries, note")
    }

    func testNoteLabelFallsBackForUntitled() {
        let untitled = Note(title: "", body: "body only", kind: .misc)
        XCTAssertEqual(AccessibilityFormatters.noteLabel(untitled), "Untitled, note")
    }
}
