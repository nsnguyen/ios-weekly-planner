import Foundation
import SwiftUI
import XCTest
@testable import WeeklyPlanner

/// Localization regression guards.
///
/// We don't ship translations in v1.0 — `Localizable.xcstrings` is seeded
/// English-only as a scaffold for translators. These tests verify that
/// the localization infrastructure (plural inflection, locale-driven
/// date formatting) actually works, so adding translations later is
/// purely a content task.
///
/// A `Text(verbatim:)` regression scanner was attempted but caused
/// simulator-side filesystem-enumeration crashes; PR review + code
/// search are the practical guardrails for that.
final class LocalizationTests: XCTestCase {
    func testPlurals_inflectCorrectly() {
        // Apple's automatic-grammar markup produces different outputs for
        // count = 1 vs count = 2 in English.
        let one = String(localized: "^[\(1) event](inflect: true)")
        let many = String(localized: "^[\(2) event](inflect: true)")
        XCTAssertNotEqual(one, many)
        XCTAssertTrue(one.contains("1"))
        XCTAssertTrue(many.contains("2"))
    }

    func testDateFormatStyle_respectsLocale() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)  // 2023-11-14
        let usFormat = date.formatted(.dateTime.month(.wide).day().year().locale(Locale(identifier: "en_US")))
        let deFormat = date.formatted(.dateTime.month(.wide).day().year().locale(Locale(identifier: "de_DE")))
        XCTAssertNotEqual(usFormat, deFormat)
    }
}
