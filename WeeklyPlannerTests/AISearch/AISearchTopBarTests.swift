import XCTest
@testable import WeeklyPlanner

/// Phase 32 (#49): the AI surface is named "Ask the planner" in all
/// user-facing copy. These asserts lock the rename so "Apple Intelligence"
/// can't drift back into UX strings (the framework name stays in code
/// symbols like `appleIntelligenceEnabled` — those are not user-facing).
@MainActor
final class AISearchTopBarTests: XCTestCase {
    func testTitleReadsAskThePlanner() {
        XCTAssertEqual(AISearchTopBar.titleText, "Ask the planner")
    }

    func testEyebrowDoesNotDuplicateTitleOrLeakAppleBranding() {
        XCTAssertEqual(AISearchTopBar.eyebrowText, "ON-DEVICE AI")
        XCTAssertFalse(AISearchTopBar.eyebrowText.localizedCaseInsensitiveContains("apple"))
    }

    func testCloseAccessibilityLabelNamesAskThePlanner() {
        XCTAssertEqual(AISearchTopBar.closeAccessibilityLabel, "Close Ask the planner")
        XCTAssertFalse(AISearchTopBar.closeAccessibilityLabel.contains("Apple Intelligence"))
    }

    func testAskInputFieldAccessibilityLabelNamesAskThePlanner() {
        XCTAssertEqual(AskInputField.inputAccessibilityLabel, "Ask the planner")
        XCTAssertFalse(AskInputField.inputAccessibilityLabel.contains("Apple Intelligence"))
    }
}
