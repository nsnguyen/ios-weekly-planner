import UIKit
import XCTest
@testable import WeeklyPlanner

final class PaperFontRegistrationTests: XCTestCase {
    private var allRegisteredNames: [String] {
        UIFont.familyNames.flatMap { UIFont.fontNames(forFamilyName: $0) }.sorted()
    }

    func testAllCasesIncludeTheFourNewFamilies() {
        XCTAssertEqual(PaperFont.allCases.count, 8)
        XCTAssertTrue(PaperFont.allCases.contains(.patrick))
        XCTAssertTrue(PaperFont.allCases.contains(.shadows))
        XCTAssertTrue(PaperFont.allCases.contains(.gochi))
        XCTAssertTrue(PaperFont.allCases.contains(.nanum))
    }

    func testEveryFamilyResolvesItsRegularFace() {
        for family in PaperFont.allCases {
            let name = family.postScriptName(for: .regular)
            XCTAssertNotNil(UIFont(name: name, size: 12),
                            "'\(name)' did not load — wrong PostScript name or missing UIAppFonts entry. Registered: \(allRegisteredNames)")
        }
    }

    func testEveryFamilyResolvesItsBoldMapping() {
        // Single-weight families map bold → their regular face; it must
        // still be a loadable name.
        for family in PaperFont.allCases {
            let name = family.postScriptName(for: .bold)
            XCTAssertNotNil(UIFont(name: name, size: 12),
                            "'\(name)' (bold mapping for \(family)) did not load. Registered: \(allRegisteredNames)")
        }
    }

    func testNewFamiliesKeepRegularLegibilityWeight() {
        for family in [PaperFont.patrick, .shadows, .gochi, .nanum] {
            XCTAssertEqual(family.weightFor(legibility: .bold), .regular,
                           "Single-weight family must not pretend to have a bolder face")
        }
    }
}
