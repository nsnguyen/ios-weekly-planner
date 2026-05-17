import SwiftUI
import XCTest
@testable import WeeklyPlanner

final class PaperThemeTests: XCTestCase {
    // MARK: - Cream

    func testCreamThemeKeyAndLabels() {
        let theme = PaperTheme.cream
        XCTAssertEqual(theme.key, .cream)
        XCTAssertEqual(theme.displayName, "Cream")
        XCTAssertEqual(theme.tag, "Vintage notebook")
    }

    func testCreamPaperColors() {
        let theme = PaperTheme.cream
        XCTAssertEqual(theme.cream.rgbaBytes, RGBA(0xFA, 0xF6, 0xE9))
        XCTAssertEqual(theme.creamHi.rgbaBytes, RGBA(0xFC, 0xF9, 0xEE))
        XCTAssertEqual(theme.creamLo.rgbaBytes, RGBA(0xF1, 0xEA, 0xD2))
        XCTAssertEqual(theme.holePunch.rgbaBytes, RGBA(0xE8, 0xE0, 0xCB))
        XCTAssertEqual(theme.bookSpine.rgbaBytes, RGBA(0x0F, 0x0A, 0x06))
    }

    func testCreamInkColors() {
        let theme = PaperTheme.cream
        XCTAssertEqual(theme.ink.rgbaBytes, RGBA(0x1A, 0x1A, 0x2A))
        XCTAssertEqual(theme.blueInk.rgbaBytes, RGBA(0x1A, 0x3A, 0x7A))
        XCTAssertEqual(theme.redInk.rgbaBytes, RGBA(0x9C, 0x2A, 0x2A))
        XCTAssertEqual(theme.greenInk.rgbaBytes, RGBA(0x2C, 0x5A, 0x2C))
        XCTAssertEqual(theme.pencil.rgbaBytes, RGBA(0x3A, 0x3A, 0x55))
    }

    // MARK: - Kraft

    func testKraftThemeKeyAndLabels() {
        let theme = PaperTheme.kraft
        XCTAssertEqual(theme.key, .kraft)
        XCTAssertEqual(theme.displayName, "Kraft")
        XCTAssertEqual(theme.tag, "Warm tan paper")
    }

    func testKraftSignatureColors() {
        let theme = PaperTheme.kraft
        XCTAssertEqual(theme.cream.rgbaBytes, RGBA(0xE6, 0xD2, 0xA8))
        XCTAssertEqual(theme.ink.rgbaBytes, RGBA(0x3A, 0x24, 0x18))
        XCTAssertEqual(theme.blueInk.rgbaBytes, RGBA(0x23, 0x46, 0x7A))
        XCTAssertEqual(theme.redInk.rgbaBytes, RGBA(0xA0, 0x30, 0x20))
        XCTAssertEqual(theme.bookSpine.rgbaBytes, RGBA(0x15, 0x0C, 0x06))
    }

    // MARK: - Midnight

    func testMidnightThemeKeyAndLabels() {
        let theme = PaperTheme.midnight
        XCTAssertEqual(theme.key, .midnight)
        XCTAssertEqual(theme.displayName, "Midnight")
        XCTAssertEqual(theme.tag, "For night use")
    }

    func testMidnightSignatureColors() {
        let theme = PaperTheme.midnight
        XCTAssertEqual(theme.cream.rgbaBytes, RGBA(0x1E, 0x1F, 0x2D))
        XCTAssertEqual(theme.ink.rgbaBytes, RGBA(0xEA, 0xE6, 0xD9))
        XCTAssertEqual(theme.blueInk.rgbaBytes, RGBA(0x7D, 0xB0, 0xF2))
        XCTAssertEqual(theme.redInk.rgbaBytes, RGBA(0xF0, 0x80, 0x80))
        XCTAssertEqual(theme.greenInk.rgbaBytes, RGBA(0x88, 0xD6, 0x80))
    }

    // MARK: - Cross-theme

    func testPaperThemeKeyResolvesToCorrectInstance() {
        XCTAssertEqual(PaperThemeKey.cream.theme, PaperTheme.cream)
        XCTAssertEqual(PaperThemeKey.kraft.theme, PaperTheme.kraft)
        XCTAssertEqual(PaperThemeKey.midnight.theme, PaperTheme.midnight)
    }

    func testAllThemesAreDistinct() {
        XCTAssertNotEqual(PaperTheme.cream, PaperTheme.kraft)
        XCTAssertNotEqual(PaperTheme.cream, PaperTheme.midnight)
        XCTAssertNotEqual(PaperTheme.kraft, PaperTheme.midnight)
    }

    func testAllThemesExistForEveryKey() {
        for key in PaperThemeKey.allCases {
            let theme = key.theme
            XCTAssertEqual(theme.key, key)
            XCTAssertFalse(theme.displayName.isEmpty)
            XCTAssertFalse(theme.tag.isEmpty)
        }
    }

    // MARK: - CSS angle helper

    func testCSSAngleZeroDegreesIsBottomToTop() {
        let points = CSSGradientAngle.unitPoints(degrees: 0)
        XCTAssertEqual(points.start.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(points.start.y, 1.0, accuracy: 0.001)
        XCTAssertEqual(points.end.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(points.end.y, 0.0, accuracy: 0.001)
    }

    func testCSSAngleNinetyDegreesIsLeftToRight() {
        let points = CSSGradientAngle.unitPoints(degrees: 90)
        XCTAssertEqual(points.start.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(points.start.y, 0.5, accuracy: 0.001)
        XCTAssertEqual(points.end.x, 1.0, accuracy: 0.001)
        XCTAssertEqual(points.end.y, 0.5, accuracy: 0.001)
    }

    func testCSSAngle160DegreesLandsInExpectedQuadrant() {
        let points = CSSGradientAngle.unitPoints(degrees: 160)
        // 160° points down-and-slightly-right, so start is up-and-slightly-left.
        XCTAssertLessThan(points.start.x, 0.5)
        XCTAssertLessThan(points.start.y, 0.5)
        XCTAssertGreaterThan(points.end.x, 0.5)
        XCTAssertGreaterThan(points.end.y, 0.5)
    }
}
