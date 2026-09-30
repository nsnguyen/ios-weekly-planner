import XCTest
@testable import WeeklyPlanner

final class PaperTemplateTests: XCTestCase {
    func testCasesAndDisplayNames() {
        XCTAssertEqual(PaperTemplate.allCases.map(\.displayName),
                       ["Ruled", "Blank", "Dot grid", "Grid"])
        XCTAssertEqual(PaperTemplate.allCases.map(\.rawValue),
                       ["ruled", "blank", "dotGrid", "grid"])
    }

    func testOnlyRuledShowsRedMargin() {
        XCTAssertTrue(PaperTemplate.ruled.showsRedMargin)
        XCTAssertFalse(PaperTemplate.blank.showsRedMargin)
        XCTAssertFalse(PaperTemplate.dotGrid.showsRedMargin)
        XCTAssertFalse(PaperTemplate.grid.showsRedMargin)
    }

    func testUserSettingsTemplateAccessorDefaultsToRuledAndRoundTrips() {
        let settings = UserSettings()
        XCTAssertEqual(settings.paperTemplate, .ruled)
        settings.paperTemplate = .dotGrid
        XCTAssertEqual(settings.templateKey, "dotGrid")
        settings.templateKey = "garbage"
        XCTAssertEqual(settings.paperTemplate, .ruled, "unknown raw falls back to ruled")
    }
}
