import XCTest
@testable import WeeklyPlanner

final class OccurrenceExpanderTests: XCTestCase {
    private var calendar: Calendar = {
        var cal = WeekMath.mondayCalendar()
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h
        return calendar.date(from: c)!
    }

    func testDailyFillsTheWindow() {
        let starts = OccurrenceExpander.occurrenceStarts(
            seriesStart: date(2026, 6, 1),
            recurrence: Recurrence(frequency: .daily),
            in: date(2026, 6, 3, 0) ..< date(2026, 6, 6, 0),
            calendar: calendar)
        XCTAssertEqual(starts, [date(2026, 6, 3), date(2026, 6, 4), date(2026, 6, 5)])
    }

    func testWeeklyIntervalTwoSkipsAlternateWeeks() {
        let starts = OccurrenceExpander.occurrenceStarts(
            seriesStart: date(2026, 6, 1), // Monday
            recurrence: Recurrence(frequency: .weekly, interval: 2),
            in: date(2026, 6, 1, 0) ..< date(2026, 7, 14, 0),
            calendar: calendar)
        XCTAssertEqual(starts, [date(2026, 6, 1), date(2026, 6, 15), date(2026, 6, 29), date(2026, 7, 13)])
    }

    func testAfterCountStopsCountingFromSeriesAnchor() {
        // 3 total occurrences from the anchor — window sees only what's left.
        let starts = OccurrenceExpander.occurrenceStarts(
            seriesStart: date(2026, 6, 1),
            recurrence: Recurrence(frequency: .daily, end: .afterCount(3)),
            in: date(2026, 6, 2, 0) ..< date(2026, 6, 30, 0),
            calendar: calendar)
        XCTAssertEqual(starts, [date(2026, 6, 2), date(2026, 6, 3)])
    }

    func testEndOnDateIsInclusiveOfThatDay() {
        let starts = OccurrenceExpander.occurrenceStarts(
            seriesStart: date(2026, 6, 1),
            recurrence: Recurrence(frequency: .daily, end: .onDate(date(2026, 6, 3, 0))),
            in: date(2026, 6, 1, 0) ..< date(2026, 6, 30, 0),
            calendar: calendar)
        XCTAssertEqual(starts, [date(2026, 6, 1), date(2026, 6, 2), date(2026, 6, 3)],
                       "An occurrence ON the end date must be included (EK semantics)")
    }

    func testExcludedOccurrencesAreSkipped() {
        let starts = OccurrenceExpander.occurrenceStarts(
            seriesStart: date(2026, 6, 1),
            recurrence: Recurrence(frequency: .daily),
            in: date(2026, 6, 1, 0) ..< date(2026, 6, 4, 0),
            excluding: [date(2026, 6, 2)],
            calendar: calendar)
        XCTAssertEqual(starts, [date(2026, 6, 1), date(2026, 6, 3)])
    }

    func testWeeklyAcrossYearBoundaryAndDSTKeepsWallClockTime() {
        // Weekly from Dec 28 2026 (Mon) — across New Year and into
        // March 2027 past the spring-forward (Mar 14 2027 in LA).
        let starts = OccurrenceExpander.occurrenceStarts(
            seriesStart: date(2026, 12, 28),
            recurrence: Recurrence(frequency: .weekly),
            in: date(2027, 1, 1, 0) ..< date(2027, 3, 23, 0),
            calendar: calendar)
        XCTAssertEqual(starts.first, date(2027, 1, 4))
        XCTAssertTrue(starts.contains(date(2027, 3, 15)), "Post-DST occurrence missing")
        // Wall-clock hour survives DST.
        for start in starts {
            XCTAssertEqual(calendar.component(.hour, from: start), 9)
        }
    }

    func testSafetyCapBoundsRunawayExpansion() {
        let starts = OccurrenceExpander.occurrenceStarts(
            seriesStart: date(2026, 6, 1),
            recurrence: Recurrence(frequency: .daily),
            in: date(2026, 6, 1, 0) ..< date(2036, 6, 1, 0),
            calendar: calendar,
            limit: 50)
        XCTAssertEqual(starts.count, 50)
    }
}
