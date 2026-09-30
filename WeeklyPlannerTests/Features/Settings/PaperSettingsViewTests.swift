import XCTest
@testable import WeeklyPlanner

@MainActor
final class PaperSettingsViewTests: XCTestCase {
    func testReminderOptionAllCasesCoversFiveStates() {
        let cases = ReminderOption.allCases
        XCTAssertEqual(cases.count, 5)
        XCTAssertEqual(cases.map(\.minutes), [nil, 5, 15, 30, 60])
    }

    func testReminderOptionDescriptionFormatting() {
        XCTAssertEqual(ReminderOption(minutes: nil).description, "None")
        XCTAssertEqual(ReminderOption(minutes: 5).description, "5 min")
        XCTAssertEqual(ReminderOption(minutes: 15).description, "15 min")
        XCTAssertEqual(ReminderOption(minutes: 30).description, "30 min")
        XCTAssertEqual(ReminderOption(minutes: 60).description, "1 hr")
    }

    func testWeekStartOffersAllSevenDays() {
        XCTAssertEqual(WeekStartDay.allCases.map(\.displayName),
                       ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
    }

    func testPaperFontCountIsTwelveSoFontCardsGridIsSixFullRows() {
        // FontCardsGrid is a 2-col grid; 12 fonts == 6 full rows.
        XCTAssertEqual(PaperFont.allCases.count, 12)
    }

    func testPaperTemplateCountIsFour() {
        XCTAssertEqual(PaperTemplate.allCases.count, 4)
    }

    func testPaperSizeCountIsFiveSoSizeSegmentedFits() {
        XCTAssertEqual(PaperSize.allCases.count, 5)
        XCTAssertEqual(PaperSize.allCases.map(\.displayName),
                       ["Small", "Medium", "Large", "XL", "XXL"])
    }

    /// Phase 32 (#49): the on-device AI toggle is named "Ask the planner"
    /// in the UI; the stored setting keeps its `appleIntelligenceEnabled`
    /// code symbol.
    func testAIToggleLabelReadsAskThePlanner() {
        XCTAssertEqual(PaperSettingsView.askThePlannerToggleLabel, "Ask the planner")
        XCTAssertFalse(PaperSettingsView.askThePlannerToggleLabel.contains("Apple Intelligence"))
    }
}
