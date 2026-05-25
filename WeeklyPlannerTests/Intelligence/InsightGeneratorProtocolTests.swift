import Foundation
import XCTest
@testable import WeeklyPlanner

@MainActor
final class InsightGeneratorProtocolTests: XCTestCase {
    func testInsightKind_allCases() {
        XCTAssertEqual(InsightKind.allCases,
                       [.encouragement, .travel, .weather, .keyword, .inbox])
    }

    func testInsightKind_colorHex_perKind() {
        XCTAssertEqual(InsightKind.travel.colorHex, "#FFE680")
        XCTAssertEqual(InsightKind.weather.colorHex, "#C9F0E0")
        XCTAssertEqual(InsightKind.keyword.colorHex, "#FFCCC9")
        XCTAssertEqual(InsightKind.inbox.colorHex, "#E0DFFF")
        XCTAssertEqual(InsightKind.encouragement.colorHex, "#FFE680")
    }

    func testInsightKind_defaultPriority_perKind() {
        XCTAssertEqual(InsightKind.travel.defaultPriority, 0)
        XCTAssertEqual(InsightKind.weather.defaultPriority, 1)
        XCTAssertEqual(InsightKind.keyword.defaultPriority, 2)
        XCTAssertEqual(InsightKind.inbox.defaultPriority, 3)
        XCTAssertEqual(InsightKind.encouragement.defaultPriority, 9)
    }

    func testDayContext_constructsCleanly() {
        let ctx = DayContext(weekOffset: 0,
                              dayIdx: 5,
                              events: [],
                              inbox: [],
                              now: Date(timeIntervalSince1970: 1_780_000_000),
                              appleIntelligenceEnabled: true)
        XCTAssertEqual(ctx.weekOffset, 0)
        XCTAssertEqual(ctx.dayIdx, 5)
        XCTAssertEqual(ctx.dayKey, "0:5")
    }
}
