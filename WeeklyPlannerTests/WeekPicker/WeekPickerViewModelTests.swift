import XCTest
@testable import WeeklyPlanner

@MainActor
final class WeekPickerViewModelTests: XCTestCase {
    /// Reference date used throughout the mock: Saturday, May 16, 2026.
    /// Matches the constant the rest of the test suite uses for week-math.
    private static func may16_2026(hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }

    /// Phase 31 (36): the window is ±24 months around the focus month —
    /// 49 months total, symmetric, oldest first.
    func testMonthWindowCenteredOnFocus() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        XCTAssertEqual(viewModel.months.count, 49)
        // Focus is May 2026 → window spans May 2024 through May 2028.
        XCTAssertEqual(viewModel.months.first?.month, 5)
        XCTAssertEqual(viewModel.months.first?.year, 2024)
        XCTAssertEqual(viewModel.months.last?.month, 5)
        XCTAssertEqual(viewModel.months.last?.year, 2028)
        // The focus month sits exactly in the middle.
        XCTAssertEqual(viewModel.months[24].month, 5)
        XCTAssertEqual(viewModel.months[24].year, 2026)
    }

    /// Phase 31 (36): regression guard against the old hard ±2 cap — months
    /// well beyond two months out exist in both directions.
    func testRangeExtendsBeyondTwoMonths() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        XCTAssertTrue(viewModel.months.contains { $0.year == 2025 && $0.month == 5 },
                      "Expected May 2025 (−12 months) in the window")
        XCTAssertTrue(viewModel.months.contains { $0.year == 2027 && $0.month == 5 },
                      "Expected May 2027 (+12 months) in the window")
    }

    func testMay2026HasFiveOrSixWeeks() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        let may = viewModel.months.first { $0.month == 5 && $0.year == 2026 }
        XCTAssertNotNil(may)
        // May 2026 (Mon-first weeks): weeks of Apr 27, May 4, May 11, May 18,
        // May 25 — exactly five rows.
        XCTAssertEqual(may?.weeks.count, 5)
    }

    func testWeekOffsetMappingForMay11_2026IsZero() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        let may = viewModel.months.first { $0.month == 5 && $0.year == 2026 }
        XCTAssertNotNil(may)
        // The week starting May 11, 2026 (Monday) should have offset 0.
        let weekOfMay11 = may?.weeks.first { week in
            week.days.contains(where: { $0.dayNumber == 11 && $0.isInDisplayedMonth })
        }
        XCTAssertEqual(weekOfMay11?.offset, 0)
    }

    func testTodayDetectedOnMay16_2026() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        let may = viewModel.months.first { $0.month == 5 && $0.year == 2026 }
        XCTAssertNotNil(may)

        let weekOfMay11 = may?.weeks.first(where: \.containsToday)
        XCTAssertNotNil(weekOfMay11)

        let saturday = weekOfMay11?.days.first { $0.dayNumber == 16 }
        XCTAssertTrue(saturday?.isToday == true)
    }
}
