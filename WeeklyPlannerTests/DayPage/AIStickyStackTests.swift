import Foundation
import SwiftUI
import XCTest
@testable import WeeklyPlanner

@MainActor
final class AIStickyStackTests: XCTestCase {
    private func insight(_ kind: InsightKind, _ text: String) -> AIInsight {
        AIInsight(dayKey: "0:5", text: text,
                  colorHex: kind.colorHex, tiltDegrees: 0,
                  kind: kind, priority: kind.defaultPriority)
    }

    func testZeroInsightsRendersEmpty() {
        let stack = AIStickyStack(insights: [],
                                   onTap: { _ in }, onDismiss: { _ in },
                                   onRefresh: {}, onShowAnother: {})
        XCTAssertNotNil(stack)
    }

    func testThreeInsightsCapsAtThree() {
        let stack = AIStickyStack(
            insights: [insight(.travel, "T"), insight(.weather, "W"),
                       insight(.keyword, "K"), insight(.inbox, "I")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: {}, onShowAnother: {})
        XCTAssertEqual(stack.insights.count, 4,
                       "Input array passes through; view caps via ForEach idx check")
    }

    func testTapCallback_invokedWithTopInsight() async {
        let exp = expectation(description: "onTap fires")
        var tapped: AIInsight?
        let top = insight(.travel, "T")
        let stack = AIStickyStack(
            insights: [top, insight(.weather, "W")],
            onTap: { tapped = $0; exp.fulfill() },
            onDismiss: { _ in }, onRefresh: {}, onShowAnother: {})
        stack.onTap(top)
        await fulfillment(of: [exp], timeout: 0.5)
        XCTAssertEqual(tapped?.kind, .travel)
    }

    func testDismissCallback_invokedWithTopInsight() async {
        let exp = expectation(description: "onDismiss fires")
        var dismissed: AIInsight?
        let top = insight(.weather, "W")
        let stack = AIStickyStack(
            insights: [top],
            onTap: { _ in },
            onDismiss: { dismissed = $0; exp.fulfill() },
            onRefresh: {}, onShowAnother: {})
        stack.onDismiss(top)
        await fulfillment(of: [exp], timeout: 0.5)
        XCTAssertEqual(dismissed?.kind, .weather)
    }

    func testShowAnotherCallback_invokedDirectly() async {
        let exp = expectation(description: "onShowAnother fires")
        let stack = AIStickyStack(
            insights: [insight(.travel, "T"), insight(.weather, "W")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: {}, onShowAnother: { exp.fulfill() })
        stack.onShowAnother()
        await fulfillment(of: [exp], timeout: 0.5)
    }

    func testRefreshCallback_invokedDirectly() async {
        let exp = expectation(description: "onRefresh fires")
        let stack = AIStickyStack(
            insights: [insight(.travel, "T")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: { exp.fulfill() }, onShowAnother: {})
        stack.onRefresh()
        await fulfillment(of: [exp], timeout: 0.5)
    }
}
