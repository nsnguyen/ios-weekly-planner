import SwiftUI
import XCTest
#if canImport(UIKit)
    import UIKit
#endif

@testable import WeeklyPlanner

final class ColorHexTests: XCTestCase {
    func testHexParsesOpaqueRGB() {
        XCTAssertEqual(Color(hex: "#FAF6E9").rgbaBytes, RGBA(0xFA, 0xF6, 0xE9))
    }

    func testHexParsesWithExplicitAlpha() {
        XCTAssertEqual(Color(hex: "#FAF6E980").rgbaBytes, RGBA(0xFA, 0xF6, 0xE9, 0x80))
    }

    func testHexHandlesMissingHashPrefix() {
        XCTAssertEqual(Color(hex: "#1A3A7A").rgbaBytes, Color(hex: "1A3A7A").rgbaBytes)
    }

    func testRgbaFactoryMatchesCSSStyleValues() {
        let rule = Color.rgba(139, 121, 80, 0.18).rgbaBytes
        XCTAssertEqual(rule.r, 139)
        XCTAssertEqual(rule.g, 121)
        XCTAssertEqual(rule.b, 80)
        XCTAssertEqual(rule.a, Int(round(0.18 * 255)), accuracy: 1)
    }
}

/// Test-only struct holding 0-255 sRGB channels. Equatable so tests can
/// compare it with `XCTAssertEqual` (raw tuples don't conform).
struct RGBA: Equatable, CustomStringConvertible {
    let r: Int
    let g: Int
    let b: Int
    let a: Int

    init(_ r: Int, _ g: Int, _ b: Int, _ a: Int = 0xFF) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    var description: String {
        String(format: "RGBA(%02X, %02X, %02X, %02X)", r, g, b, a)
    }
}

extension Color {
    /// Test-only bridge that resolves the color through UIColor and returns 0-255 channels.
    /// Lives on Color (rather than the test class) so theme tests can use the same helper.
    var rgbaBytes: RGBA {
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBA(Int(round(r * 255)),
                    Int(round(g * 255)),
                    Int(round(b * 255)),
                    Int(round(a * 255)))
    }
}
