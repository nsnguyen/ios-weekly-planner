import XCTest
@testable import WeeklyPlanner

/// Phase 29 tweak (14): the destructive control reads "Delete" (the confirm
/// alert already says "Delete this event?"), replacing the old "Tear out this
/// page" copy. The visible label is exposed as a testable static so this can
/// be asserted without a view-introspection dependency.
@MainActor
final class EventDeleteButtonTests: XCTestCase {
    func testVisibleLabelIsDelete() {
        XCTAssertEqual(EventDeleteButton.label, "Delete")
    }

    func testVisibleLabelIsNotTheOldTearOutCopy() {
        XCTAssertNotEqual(EventDeleteButton.label, "Tear out this page")
        XCTAssertFalse(EventDeleteButton.label.lowercased().contains("tear out"))
    }
}
