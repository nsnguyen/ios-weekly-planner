import XCTest
@testable import WeeklyPlanner

@MainActor
final class NotificationContentBuilderTests: XCTestCase {

    func testTitleTruncatedAt64Chars() {
        let long = String(repeating: "x", count: 70)
        let content = NotificationContentBuilder.timeBased(
            title: long,
            startsAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
            location: nil,
            minutesBefore: 15
        )
        XCTAssertEqual(content.title.count, 64)
        XCTAssertTrue(content.title.hasSuffix("…"))
    }

    func testTimeBasedBodyContainsMinutes() {
        let content = NotificationContentBuilder.timeBased(
            title: "Lunch",
            startsAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
            location: "Café Bleu",
            minutesBefore: 15
        )
        XCTAssertTrue(content.body.contains("15"))
        XCTAssertTrue(content.subtitle.contains("Café Bleu"))
    }

    func testLocationBasedBodyMentionsArrival() {
        let content = NotificationContentBuilder.locationBased(
            title: "Lunch",
            locationName: "Marina"
        )
        XCTAssertTrue(content.body.contains("Marina"))
    }
}
