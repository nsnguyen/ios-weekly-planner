import SwiftUI
import XCTest
@testable import WeeklyPlanner

final class PaperFontTests: XCTestCase {
    func testCaveatWeightsMapToDistinctPostScriptNames() {
        let caveat = PaperFont.caveat
        XCTAssertEqual(caveat.postScriptName(for: .regular), "Caveat-Regular")
        XCTAssertEqual(caveat.postScriptName(for: .medium), "Caveat-Medium")
        XCTAssertEqual(caveat.postScriptName(for: .semibold), "Caveat-SemiBold")
        XCTAssertEqual(caveat.postScriptName(for: .bold), "Caveat-Bold")
        XCTAssertEqual(caveat.postScriptName(for: .heavy), "Caveat-Bold")
        XCTAssertEqual(caveat.postScriptName(for: .black), "Caveat-Bold")
    }

    func testArchitectsIgnoresWeight() {
        let architects = PaperFont.architects
        XCTAssertEqual(architects.postScriptName(for: .regular), "ArchitectsDaughter-Regular")
        XCTAssertEqual(architects.postScriptName(for: .bold), "ArchitectsDaughter-Regular")
        XCTAssertEqual(architects.postScriptName(for: .light), "ArchitectsDaughter-Regular")
    }

    func testKalamWeightsMapToThreeShippedFiles() {
        let kalam = PaperFont.kalam
        XCTAssertEqual(kalam.postScriptName(for: .light), "Kalam-Light")
        XCTAssertEqual(kalam.postScriptName(for: .thin), "Kalam-Light")
        XCTAssertEqual(kalam.postScriptName(for: .regular), "Kalam-Regular")
        XCTAssertEqual(kalam.postScriptName(for: .medium), "Kalam-Regular")
        XCTAssertEqual(kalam.postScriptName(for: .bold), "Kalam-Bold")
        XCTAssertEqual(kalam.postScriptName(for: .heavy), "Kalam-Bold")
    }

    func testIndieIgnoresWeight() {
        let indie = PaperFont.indie
        XCTAssertEqual(indie.postScriptName(for: .regular), "IndieFlower-Regular")
        XCTAssertEqual(indie.postScriptName(for: .bold), "IndieFlower-Regular")
    }

    func testFontAtSizeReturnsAFont() {
        // Smoke check that the public API compiles and returns a Font value.
        for family in PaperFont.allCases {
            _ = family.font(at: 22, weight: .semibold)
        }
    }

    func testDisplayNamesAreNonEmpty() {
        for family in PaperFont.allCases {
            XCTAssertFalse(family.displayName.isEmpty)
        }
    }
}

final class PaperSizeTests: XCTestCase {
    func testScaleFactorsMatchSpec() {
        XCTAssertEqual(PaperSize.s.scale, 0.90, accuracy: 0.001)
        XCTAssertEqual(PaperSize.m.scale, 1.00, accuracy: 0.001)
        XCTAssertEqual(PaperSize.l.scale, 1.14, accuracy: 0.001)
    }

    func testAllSizesHaveDistinctScale() {
        let scales = PaperSize.allCases.map(\.scale)
        XCTAssertEqual(Set(scales).count, scales.count)
    }
}
