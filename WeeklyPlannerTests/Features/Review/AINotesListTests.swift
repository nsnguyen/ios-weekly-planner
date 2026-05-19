import XCTest
@testable import WeeklyPlanner

final class AINotesListTests: XCTestCase {
    func testInkResolvesToThemeColorMapping() {
        XCTAssertEqual(AINotesList.inkKey(.dark), "ink")
        XCTAssertEqual(AINotesList.inkKey(.green), "greenInk")
        XCTAssertEqual(AINotesList.inkKey(.red), "redInk")
        XCTAssertEqual(AINotesList.inkKey(.blue), "blueInk")
    }
}
