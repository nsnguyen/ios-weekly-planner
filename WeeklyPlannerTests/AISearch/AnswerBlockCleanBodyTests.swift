import XCTest
@testable import WeeklyPlanner

final class AnswerBlockCleanBodyTests: XCTestCase {
    func testStripsBoldAsterisks() {
        XCTAssertEqual(
            AnswerBlock.cleanBody("Friday afternoon: **meeting at 4 PM**."),
            "Friday afternoon: meeting at 4 PM."
        )
    }

    func testStripsSoloAsterisks() {
        XCTAssertEqual(
            AnswerBlock.cleanBody("*Meet with Sara* at 3 PM."),
            "Meet with Sara at 3 PM."
        )
    }

    func testStripsLeadingBulletDashes() {
        let raw = """
        Here's your day:
        - First meeting at 9 AM
        - Lunch with Mei at noon
        """
        let cleaned = AnswerBlock.cleanBody(raw)
        XCTAssertFalse(cleaned.contains("- "))
        XCTAssertTrue(cleaned.contains("First meeting at 9 AM"))
        XCTAssertTrue(cleaned.contains("Lunch with Mei at noon"))
    }

    func testStripsMarkdownHeaders() {
        XCTAssertEqual(
            AnswerBlock.cleanBody("## Friday\nNothing on your plate."),
            "Friday\nNothing on your plate."
        )
    }

    func testPreservesPlainText() {
        XCTAssertEqual(
            AnswerBlock.cleanBody("Three meetings on Friday: standup, design, and review."),
            "Three meetings on Friday: standup, design, and review."
        )
    }
}
