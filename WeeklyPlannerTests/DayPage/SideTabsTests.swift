import SwiftUI
import UIKit
import XCTest
@testable import WeeklyPlanner

final class SideTabsTests: XCTestCase {
    func testPastelColorsMatchSpec() {
        XCTAssertEqual(SideTab.pastel(forIdx: 0).rgbaBytes, RGBA(0xE8, 0xD9, 0xB7))
        XCTAssertEqual(SideTab.pastel(forIdx: 1).rgbaBytes, RGBA(0xD9, 0xC9, 0xE3))
        XCTAssertEqual(SideTab.pastel(forIdx: 2).rgbaBytes, RGBA(0xC8, 0xDD, 0xE6))
        XCTAssertEqual(SideTab.pastel(forIdx: 3).rgbaBytes, RGBA(0xE4, 0xD3, 0xC2))
        XCTAssertEqual(SideTab.pastel(forIdx: 4).rgbaBytes, RGBA(0xD9, 0xE4, 0xC6))
        XCTAssertEqual(SideTab.pastel(forIdx: 5).rgbaBytes, RGBA(0xE7, 0xC7, 0xC7))
        XCTAssertEqual(SideTab.pastel(forIdx: 6).rgbaBytes, RGBA(0xCF, 0xD4, 0xDC))
    }

    func testPastelFallsBackToMondayForOutOfRange() {
        XCTAssertEqual(SideTab.pastel(forIdx: 99).rgbaBytes,
                       SideTab.pastel(forIdx: 0).rgbaBytes)
        XCTAssertEqual(SideTab.pastel(forIdx: -1).rgbaBytes,
                       SideTab.pastel(forIdx: 0).rgbaBytes)
    }

    func testLongWeekdayLabelsCanScaleInsideFixedTabHeight() {
        let layout = SideTab.labelLayout
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

        XCTAssertLessThan(layout.minimumScaleFactor, 1)
        XCTAssertLessThanOrEqual(layout.trackLength, Spacing.sideTabHeight)
        XCTAssertLessThanOrEqual(layout.lineBoxHeight, Spacing.sideTabWidth)

        for family in PaperFont.allCases {
            guard let font = UIFont(name: family.postScriptName(for: .bold), size: layout.fontSize) else {
                XCTFail("Missing font for \(family)")
                continue
            }

            XCTAssertLessThanOrEqual(font.lineHeight,
                                     layout.lineBoxHeight + 0.5,
                                     "\(family.displayName)'s line height needs to fit inside the tab width after rotation")

            for name in names {
                let displayText = name.uppercased()
                let naturalWidth = (displayText as NSString).size(withAttributes: [
                    .font: font,
                    .kern: layout.tracking,
                ]).width

                XCTAssertLessThanOrEqual(naturalWidth * layout.minimumScaleFactor,
                                         layout.trackLength + 0.5,
                                         "\(displayText) in \(family.displayName) needs to fit inside the rotated tab track")
            }
        }
    }
}
