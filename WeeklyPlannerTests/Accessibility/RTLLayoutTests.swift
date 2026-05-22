import Foundation
import SwiftUI
import XCTest
@testable import WeeklyPlanner

@MainActor
final class RTLLayoutTests: XCTestCase {
    func testPageFlipDeltaXSign_invertsInRTL() {
        XCTAssertEqual(RTLMath.adjustDeltaX(50, for: .leftToRight), 50)
        XCTAssertEqual(RTLMath.adjustDeltaX(50, for: .rightToLeft), -50)
        XCTAssertEqual(RTLMath.adjustDeltaX(-25, for: .leftToRight), -25)
        XCTAssertEqual(RTLMath.adjustDeltaX(-25, for: .rightToLeft), 25)
    }

    func testHeaderRotationSign_flipsInRTL() {
        XCTAssertEqual(RTLMath.headerRotationDegrees(for: .leftToRight), -3.0)
        XCTAssertEqual(RTLMath.headerRotationDegrees(for: .rightToLeft), 3.0)
    }

    func testSideTabAlignment_byDirection() {
        XCTAssertEqual(RTLMath.sideTabAlignment(for: .leftToRight), .leading)
        XCTAssertEqual(RTLMath.sideTabAlignment(for: .rightToLeft), .trailing)
    }
}
