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

    func testWeekStartHasMondayAndSundayOnly() {
        let cases = WeekStart.allCases
        XCTAssertEqual(cases, [.monday, .sunday])
        XCTAssertEqual(cases.map(\.description), ["Monday", "Sunday"])
    }

    func testPaperThemeKeyCountMatchesGridColumnCount() {
        // ThemeCardsGrid is a 3-col grid; we want exactly 3 themes so each
        // row is full. If a fourth theme lands, this test will fail and
        // remind us to revisit the grid columns.
        XCTAssertEqual(PaperThemeKey.allCases.count, 3)
    }

    func testPaperFontCountIsEightSoFontCardsGridIsFourFullRows() {
        // FontCardsGrid is a 2-col grid; 8 fonts == 4 full rows.
        XCTAssertEqual(PaperFont.allCases.count, 8)
    }

    func testPaperSizeCountIsThreeSoSizeSegmentedFits() {
        XCTAssertEqual(PaperSize.allCases.count, 3)
        XCTAssertEqual(PaperSize.allCases.map(\.displayName), ["Small", "Medium", "Large"])
    }

    /// Phase 32 (#49): the on-device AI toggle is named "Ask the planner"
    /// in the UI; the stored setting keeps its `appleIntelligenceEnabled`
    /// code symbol.
    func testAIToggleLabelReadsAskThePlanner() {
        XCTAssertEqual(PaperSettingsView.askThePlannerToggleLabel, "Ask the planner")
        XCTAssertFalse(PaperSettingsView.askThePlannerToggleLabel.contains("Apple Intelligence"))
    }
}
