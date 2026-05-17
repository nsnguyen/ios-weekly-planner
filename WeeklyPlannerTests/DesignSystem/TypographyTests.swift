import SwiftUI
import XCTest
@testable import WeeklyPlanner

final class TypographyTests: XCTestCase {
    func testPageHeaderRampMatchesSpec() {
        XCTAssertEqual(Typography.pageWeekdayTitle.size, 30)
        XCTAssertEqual(Typography.pageWeekdayTitle.weight, .bold)
        XCTAssertEqual(Typography.pageWeekdayTitle.kind, .handwriting)

        XCTAssertEqual(Typography.pageDateNumber.size, 62)
        XCTAssertEqual(Typography.pageDateNumber.weight, .bold)
        XCTAssertEqual(Typography.pageDateNumber.rotationDegrees, -3)

        XCTAssertEqual(Typography.pageMonthCaption.size, 12)
        XCTAssertTrue(Typography.pageMonthCaption.italic)
        if case let .named(name) = Typography.pageMonthCaption.kind {
            XCTAssertEqual(name, "Cochin-Italic")
        } else {
            XCTFail("pageMonthCaption should use a named italic font")
        }
    }

    func testEventRampMatchesSpec() {
        XCTAssertEqual(Typography.eventTitle.size, 21)
        XCTAssertEqual(Typography.eventTitle.weight, .semibold)
        XCTAssertEqual(Typography.eventLocation.size, 12)
        XCTAssertTrue(Typography.eventLocation.italic)
        XCTAssertEqual(Typography.eventTime.size, 13)
        XCTAssertTrue(Typography.eventTime.tabularNumerals)
    }

    func testTaskAndStickyRampMatchesSpec() {
        XCTAssertEqual(Typography.taskLabel.size, 17)
        XCTAssertEqual(Typography.taskLabel.weight, .medium)
        XCTAssertEqual(Typography.stickyBody.size, 13)
        XCTAssertEqual(Typography.stickyBody.weight, .semibold)
    }

    func testEyebrowRampMatchesSpec() {
        let eyebrow = Typography.eyebrow
        XCTAssertEqual(eyebrow.size, 10)
        XCTAssertEqual(eyebrow.weight, .bold)
        XCTAssertEqual(eyebrow.kind, .system)
        XCTAssertTrue(eyebrow.uppercase)
        XCTAssertGreaterThanOrEqual(eyebrow.tracking, 1.4)

        let weekEyebrow = Typography.weekChromeEyebrow
        XCTAssertEqual(weekEyebrow.tracking, 1.6, accuracy: 0.001)
        XCTAssertEqual(weekEyebrow.opacity, 0.65, accuracy: 0.001)
    }

    func testReviewRampMatchesSpec() {
        XCTAssertEqual(Typography.reviewTitle.size, 28)
        XCTAssertEqual(Typography.reviewTitle.weight, .bold)
        XCTAssertEqual(Typography.reviewPercent.size, 48)
        XCTAssertEqual(Typography.reviewPercent.rotationDegrees, -3)
    }

    func testFontResolvesForEveryHandwritingFamily() {
        let entry = Typography.eventTitle
        for family in PaperFont.allCases {
            _ = entry.font(in: family)
        }
    }
}
