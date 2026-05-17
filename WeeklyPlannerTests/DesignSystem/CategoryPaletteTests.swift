import SwiftUI
import XCTest
@testable import WeeklyPlanner

final class CategoryPaletteTests: XCTestCase {
    func testDotColorsMatchSpec() {
        XCTAssertEqual(CategoryPalette.dot(.work).rgbaBytes, RGBA(0x0A, 0x84, 0xFF))
        XCTAssertEqual(CategoryPalette.dot(.personal).rgbaBytes, RGBA(0xBF, 0x5A, 0xF2))
        XCTAssertEqual(CategoryPalette.dot(.health).rgbaBytes, RGBA(0x30, 0xD1, 0x58))
        XCTAssertEqual(CategoryPalette.dot(.family).rgbaBytes, RGBA(0xFF, 0x37, 0x5F))
        XCTAssertEqual(CategoryPalette.dot(.focus).rgbaBytes, RGBA(0xFF, 0x9F, 0x0A))
        XCTAssertEqual(CategoryPalette.dot(.travel).rgbaBytes, RGBA(0x64, 0xD2, 0xFF))
    }

    func testBgLightAndBgDarkAlphaFromDot() {
        for category in Category.allCases {
            let dot = CategoryPalette.dot(category).rgbaBytes
            let light = CategoryPalette.bgLight(category).rgbaBytes
            let dark = CategoryPalette.bgDark(category).rgbaBytes

            // Same RGB; only alpha differs.
            XCTAssertEqual(light.r, dot.r, "bgLight RGB drift for \(category)")
            XCTAssertEqual(light.g, dot.g)
            XCTAssertEqual(light.b, dot.b)
            XCTAssertEqual(dark.r, dot.r)
            XCTAssertEqual(dark.g, dot.g)
            XCTAssertEqual(dark.b, dot.b)

            XCTAssertEqual(light.a, Int(round(0.12 * 255)), accuracy: 1)
            XCTAssertEqual(dark.a, Int(round(0.22 * 255)), accuracy: 1)
        }
    }

    // MARK: - inkColor follows the theme for work/health/family

    func testWorkInkFollowsThemeBlueInk() {
        XCTAssertEqual(CategoryPalette.inkColor(.work, in: .cream).rgbaBytes,
                       PaperTheme.cream.blueInk.rgbaBytes)
        XCTAssertEqual(CategoryPalette.inkColor(.work, in: .midnight).rgbaBytes,
                       PaperTheme.midnight.blueInk.rgbaBytes)
        // Midnight blueInk should be light-blue #7DB0F2 (sanity check, mock spec)
        XCTAssertEqual(CategoryPalette.inkColor(.work, in: .midnight).rgbaBytes,
                       RGBA(0x7D, 0xB0, 0xF2))
    }

    func testHealthInkFollowsThemeGreenInk() {
        XCTAssertEqual(CategoryPalette.inkColor(.health, in: .cream).rgbaBytes,
                       PaperTheme.cream.greenInk.rgbaBytes)
    }

    func testFamilyInkFollowsThemeRedInk() {
        XCTAssertEqual(CategoryPalette.inkColor(.family, in: .kraft).rgbaBytes,
                       PaperTheme.kraft.redInk.rgbaBytes)
    }

    // MARK: - inkColor is theme-independent for personal/focus/travel

    func testPersonalInkIsThemeIndependent() {
        let expected = RGBA(0x5A, 0x2A, 0x7A)
        XCTAssertEqual(CategoryPalette.inkColor(.personal, in: .cream).rgbaBytes, expected)
        XCTAssertEqual(CategoryPalette.inkColor(.personal, in: .kraft).rgbaBytes, expected)
        XCTAssertEqual(CategoryPalette.inkColor(.personal, in: .midnight).rgbaBytes, expected)
    }

    func testFocusInkIsThemeIndependent() {
        let expected = RGBA(0x8A, 0x5A, 0x1A)
        XCTAssertEqual(CategoryPalette.inkColor(.focus, in: .cream).rgbaBytes, expected)
        XCTAssertEqual(CategoryPalette.inkColor(.focus, in: .kraft).rgbaBytes, expected)
        XCTAssertEqual(CategoryPalette.inkColor(.focus, in: .midnight).rgbaBytes, expected)
    }

    func testTravelInkIsThemeIndependent() {
        let expected = RGBA(0x1A, 0x6A, 0x8A)
        XCTAssertEqual(CategoryPalette.inkColor(.travel, in: .cream).rgbaBytes, expected)
        XCTAssertEqual(CategoryPalette.inkColor(.travel, in: .kraft).rgbaBytes, expected)
        XCTAssertEqual(CategoryPalette.inkColor(.travel, in: .midnight).rgbaBytes, expected)
    }

    // MARK: - Display labels

    func testDisplayNamesAreNonEmptyForAllCategories() {
        for category in Category.allCases {
            XCTAssertFalse(CategoryPalette.displayName(category).isEmpty)
        }
    }
}
