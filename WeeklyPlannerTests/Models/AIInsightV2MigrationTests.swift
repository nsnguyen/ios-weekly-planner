import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class AIInsightV2MigrationTests: XCTestCase {
    func testNewInsight_defaultsToEncouragementKind() {
        let insight = AIInsight(dayKey: "0:5",
                                 text: "Don't forget Sara's gift!",
                                 colorHex: "#FFE680",
                                 tiltDegrees: 4)
        XCTAssertEqual(insight.kindRaw, "encouragement")
        XCTAssertEqual(insight.kind, .encouragement)
        XCTAssertNil(insight.actionURL)
        XCTAssertEqual(insight.priority, 9)
    }

    func testNewInsight_explicitKind_storesAndRoundTripsViaRawValue() {
        let insight = AIInsight(dayKey: "0:5",
                                 text: "Leave by 9:35 for dentist",
                                 colorHex: "#FFE680",
                                 tiltDegrees: 4,
                                 kind: .travel,
                                 actionURL: "http://maps.apple.com/?daddr=37.78,-122.41",
                                 priority: 0)
        XCTAssertEqual(insight.kindRaw, "travel")
        XCTAssertEqual(insight.kind, .travel)
        XCTAssertEqual(insight.actionURL, "http://maps.apple.com/?daddr=37.78,-122.41")
        XCTAssertEqual(insight.priority, 0)
    }

    func testMultipleInsightsForSameDay_canCoexistAcrossKinds() throws {
        let container = try SwiftDataStack.inMemoryContainer()
        let context = container.mainContext

        let travel = AIInsight(dayKey: "0:5", text: "T", colorHex: "#FFE680",
                                tiltDegrees: 0, kind: .travel, priority: 0)
        let weather = AIInsight(dayKey: "0:5", text: "W", colorHex: "#C9F0E0",
                                 tiltDegrees: 0, kind: .weather, priority: 1)
        context.insert(travel)
        context.insert(weather)
        try context.save()

        let all = try context.fetch(FetchDescriptor<AIInsight>())
        XCTAssertEqual(all.count, 2,
                       "Multiple insights per dayKey must coexist once kind is added")
    }
}
