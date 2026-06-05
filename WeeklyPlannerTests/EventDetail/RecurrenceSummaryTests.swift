import XCTest
@testable import WeeklyPlanner

final class RecurrenceSummaryTests: XCTestCase {
    private func monday() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 1; c.hour = 9 // Mon Jun 1 2026
        return WeekMath.mondayCalendar().date(from: c)!
    }

    func testWeeklyMentionsTheWeekday() {
        let text = RecurrenceSummary.text(for: Recurrence(frequency: .weekly), seriesStart: monday())
        XCTAssertEqual(text, "Every week on Mon")
    }

    func testIntervalPluralizes() {
        let text = RecurrenceSummary.text(for: Recurrence(frequency: .weekly, interval: 2), seriesStart: monday())
        XCTAssertEqual(text, "Every 2 weeks on Mon")
    }

    func testDailyUntilDate() {
        var c = DateComponents(); c.year = 2026; c.month = 6; c.day = 30
        let end = WeekMath.mondayCalendar().date(from: c)!
        let text = RecurrenceSummary.text(for: Recurrence(frequency: .daily, end: .onDate(end)), seriesStart: monday())
        XCTAssertEqual(text, "Every day until Jun 30")
    }

    func testMonthlyAfterCount() {
        let text = RecurrenceSummary.text(for: Recurrence(frequency: .monthly, end: .afterCount(5)), seriesStart: monday())
        XCTAssertEqual(text, "Every month, 5 times")
    }

    func testYearlyNeverEnding() {
        let text = RecurrenceSummary.text(for: Recurrence(frequency: .yearly), seriesStart: monday())
        XCTAssertEqual(text, "Every year")
    }
}
