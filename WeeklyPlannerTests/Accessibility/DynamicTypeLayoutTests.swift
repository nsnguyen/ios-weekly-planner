import Foundation
import SwiftUI
import XCTest
@testable import WeeklyPlanner

@MainActor
final class DynamicTypeLayoutTests: XCTestCase {
    func testTimeGutterWidth_isStandardBelowAX2() {
        XCTAssertEqual(DynamicTypeLayout.timeGutterWidth(at: .large), 48)
        XCTAssertEqual(DynamicTypeLayout.timeGutterWidth(at: .xxxLarge), 48)
        XCTAssertEqual(DynamicTypeLayout.timeGutterWidth(at: .accessibility1), 48)
    }

    func testTimeGutterWidth_isWideAtAX2AndAbove() {
        XCTAssertEqual(DynamicTypeLayout.timeGutterWidth(at: .accessibility2), 64)
        XCTAssertEqual(DynamicTypeLayout.timeGutterWidth(at: .accessibility5), 64)
    }

    func testSideTabWidth_thresholds() {
        XCTAssertEqual(DynamicTypeLayout.sideTabWidth(at: .large), 22)
        XCTAssertEqual(DynamicTypeLayout.sideTabWidth(at: .accessibility1), 22)
        XCTAssertEqual(DynamicTypeLayout.sideTabWidth(at: .accessibility2), 32)
        XCTAssertEqual(DynamicTypeLayout.sideTabWidth(at: .accessibility5), 32)
    }

    func testTabBarLabelStyle_thresholds() {
        XCTAssertEqual(DynamicTypeLayout.tabBarLabelStyle(at: .large), .full)
        XCTAssertEqual(DynamicTypeLayout.tabBarLabelStyle(at: .accessibility2), .full)
        XCTAssertEqual(DynamicTypeLayout.tabBarLabelStyle(at: .accessibility3), .truncate)
        XCTAssertEqual(DynamicTypeLayout.tabBarLabelStyle(at: .accessibility4), .iconOnly)
        XCTAssertEqual(DynamicTypeLayout.tabBarLabelStyle(at: .accessibility5), .iconOnly)
    }
}
