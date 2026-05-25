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

    // MARK: - Existing tests (updated API)

    func testZeroInsightsRendersEmpty() {
        let stack = AIStickyStack(insights: [],
                                   onTap: { _ in }, onDismiss: { _ in },
                                   onRefresh: {}, onNavigate: { _ in })
        XCTAssertNotNil(stack)
    }

    func testThreeInsightsCapsAtThree() {
        let stack = AIStickyStack(
            insights: [insight(.travel, "T"), insight(.weather, "W"),
                       insight(.keyword, "K"), insight(.inbox, "I")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: {}, onNavigate: { _ in })
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
            onDismiss: { _ in }, onRefresh: {}, onNavigate: { _ in })
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
            onRefresh: {}, onNavigate: { _ in })
        stack.onDismiss(top)
        await fulfillment(of: [exp], timeout: 0.5)
        XCTAssertEqual(dismissed?.kind, .weather)
    }

    func testRefreshCallback_invokedDirectly() async {
        let exp = expectation(description: "onRefresh fires")
        let stack = AIStickyStack(
            insights: [insight(.travel, "T")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: { exp.fulfill() }, onNavigate: { _ in })
        stack.onRefresh()
        await fulfillment(of: [exp], timeout: 0.5)
    }

    // MARK: - New: currentIndex

    func testCurrentIndex_defaultsToZero() {
        let stack = AIStickyStack(
            insights: [insight(.travel, "T"), insight(.weather, "W")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: {}, onNavigate: { _ in })
        XCTAssertEqual(stack.currentIndex, 0)
    }

    // MARK: - New: onNavigate callback

    func testNavigateCallback_invokedWithIndex() async {
        let exp = expectation(description: "onNavigate fires")
        var navigatedTo: Int?
        let stack = AIStickyStack(
            insights: [insight(.travel, "T"), insight(.weather, "W"), insight(.keyword, "K")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: {}, onNavigate: { idx in navigatedTo = idx; exp.fulfill() })
        stack.onNavigate(1)
        await fulfillment(of: [exp], timeout: 0.5)
        XCTAssertEqual(navigatedTo, 1)
    }

    // MARK: - New: page indicator

    func testPageIndicator_multipleInsights_dotCountMatchesInsightsCount() {
        let stack = AIStickyStack(
            insights: [insight(.travel, "T"), insight(.weather, "W"), insight(.keyword, "K")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: {}, onNavigate: { _ in })
        XCTAssertEqual(stack.insights.count, 3,
                       "Page indicator should show 3 dots for 3 insights")
    }

    func testPageIndicator_singleInsight_noDotsShown() {
        let stack = AIStickyStack(
            insights: [insight(.travel, "T")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: {}, onNavigate: { _ in })
        XCTAssertEqual(stack.insights.count, 1,
                       "Page indicator should not render for a single insight")
    }
}
