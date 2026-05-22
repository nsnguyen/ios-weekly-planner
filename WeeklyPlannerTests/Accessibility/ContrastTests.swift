import Foundation
import SwiftUI
import XCTest
@testable import WeeklyPlanner

@MainActor
final class ContrastTests: XCTestCase {
    func testInk3Alpha_isRaisedTo50PercentInCreamTheme() {
        let cream = PaperTheme.cream
        let expected = Color.rgba(26, 26, 42, 0.50)
        XCTAssertEqual(cream.ink3, expected)
    }

    func testInk3Alpha_isRaisedTo50PercentInKraftTheme() {
        let kraft = PaperTheme.kraft
        let expected = Color.rgba(58, 36, 24, 0.50)
        XCTAssertEqual(kraft.ink3, expected)
    }

    func testInk3Alpha_isRaisedTo50PercentInMidnightTheme() {
        let midnight = PaperTheme.midnight
        let expected = Color.rgba(234, 230, 217, 0.50)
        XCTAssertEqual(midnight.ink3, expected)
    }

    func testInkDecorative_existsAtLowerAlpha_inAllThemes() {
        XCTAssertEqual(PaperTheme.cream.inkDecorative, Color.rgba(26, 26, 42, 0.30))
        XCTAssertEqual(PaperTheme.kraft.inkDecorative, Color.rgba(58, 36, 24, 0.30))
        XCTAssertEqual(PaperTheme.midnight.inkDecorative, Color.rgba(234, 230, 217, 0.30))
    }

    func testBoldTextWeight_swapForCaveat() {
        XCTAssertEqual(PaperFont.caveat.weightFor(legibility: .regular), .regular)
        XCTAssertEqual(PaperFont.caveat.weightFor(legibility: .bold), .semibold)
    }

    func testBoldTextWeight_swapForKalam() {
        XCTAssertEqual(PaperFont.kalam.weightFor(legibility: .regular), .regular)
        XCTAssertEqual(PaperFont.kalam.weightFor(legibility: .bold), .bold)
    }
}
