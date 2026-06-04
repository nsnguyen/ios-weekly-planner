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

    // MARK: - Phase 31 (35): displayed month + step/jump

    func testDisplayedMonthStartsAtFocusMonth() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        XCTAssertEqual(viewModel.displayedMonth?.id, "2026-05")
        // Focus offset +6 → Mon Jun 22, 2026 → June is the focus month.
        let shifted = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 6)
        XCTAssertEqual(shifted.displayedMonth?.id, "2026-06")
    }

    /// Phase 31 (35): jumping to an arbitrary month/year selects that month
    /// for display, leaves the week *selection* untouched, and the target
    /// month's week offsets are correct (Mon Mar 1 2027 = +42 weeks from
    /// Mon May 11 2026 — exactly 294 days).
    func testJumpToMonthYear() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        let target = viewModel.jumpTo(year: 2027, month: 3)
        XCTAssertNotNil(target)
        XCTAssertEqual(viewModel.displayedMonth?.id, "2027-03")
        XCTAssertEqual(viewModel.displayedMonth?.title, "March 2027")
        XCTAssertEqual(viewModel.selectedWeekOffset, 0,
                       "Jumping must not change the selected week")
        let firstWeek = target?.weeks.first
        XCTAssertEqual(firstWeek?.offset, 42)
        XCTAssertEqual(firstWeek?.days.first?.id, "2027-03-01")
    }

    func testJumpOutsideWindowReturnsNil() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        XCTAssertNil(viewModel.jumpTo(year: 2030, month: 1))
        XCTAssertEqual(viewModel.displayedMonth?.id, "2026-05",
                       "Failed jump must not move the displayed month")
    }

    func testStepMonthAndYearClampAtWindowEdges() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        viewModel.stepMonth(by: 1)
        XCTAssertEqual(viewModel.displayedMonth?.id, "2026-06")
        viewModel.stepMonth(by: 12)
        XCTAssertEqual(viewModel.displayedMonth?.id, "2027-06")
        // Clamp forward: +24 from June 2027 overshoots → lands on May 2028.
        viewModel.stepMonth(by: 24)
        XCTAssertEqual(viewModel.displayedMonth?.id, "2028-05")
        XCTAssertFalse(viewModel.canStepForward)
        XCTAssertTrue(viewModel.canStepBackward)
        // Clamp backward to the window start.
        viewModel.stepMonth(by: -100)
        XCTAssertEqual(viewModel.displayedMonth?.id, "2024-05")
        XCTAssertFalse(viewModel.canStepBackward)
        XCTAssertTrue(viewModel.canStepForward)
    }

    // MARK: - Phase 31 (36): offset integrity at far-out months

    /// Hard-coded year-boundary anchors: the week containing Jan 1 2027
    /// starts Mon Dec 28 2026 (+33 weeks from Mon May 11 2026); the week
    /// containing Jan 1 2026 starts Mon Dec 29 2025 (−19 weeks).
    func testWeekOffsetCorrectAcrossYearBoundary() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)

        let jan2027 = viewModel.months.first { $0.year == 2027 && $0.month == 1 }
        XCTAssertNotNil(jan2027)
        let newYearWeek2027 = jan2027?.weeks.first { week in
            week.days.contains { $0.id == "2027-01-01" }
        }
        XCTAssertEqual(newYearWeek2027?.offset, 33)
        XCTAssertEqual(newYearWeek2027?.days.first?.id, "2026-12-28")

        let jan2026 = viewModel.months.first { $0.year == 2026 && $0.month == 1 }
        XCTAssertNotNil(jan2026)
        let newYearWeek2026 = jan2026?.weeks.first { week in
            week.days.contains { $0.id == "2026-01-01" }
        }
        XCTAssertEqual(newYearWeek2026?.offset, -19)
        XCTAssertEqual(newYearWeek2026?.days.first?.id, "2025-12-29")
    }

    /// Sweep the whole ±24-month window: deduped week offsets must form a
    /// gapless contiguous integer range, every week must start on a Monday
    /// and hold exactly 7 days, and offset 0 must start on Mon May 11 2026.
    /// Catches integer drift across year boundaries and DST transitions
    /// (Mar/Nov 2024–2028 all fall inside the window).
    func testWeekOffsetsContiguousAcrossWholeWindow() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        let calendar = WeekMath.mondayCalendar()

        var mondayByOffset: [Int: String] = [:]
        for month in viewModel.months {
            for week in month.weeks {
                XCTAssertEqual(week.days.count, 7, "Week \(week.offset) must span 7 days")
                guard let monday = week.days.first else { continue }
                XCTAssertEqual(calendar.component(.weekday, from: monday.date), 2,
                               "Week \(week.offset) must start on a Monday")
                if let existing = mondayByOffset[week.offset] {
                    XCTAssertEqual(existing, monday.id,
                                   "Offset \(week.offset) maps to two different Mondays")
                } else {
                    mondayByOffset[week.offset] = monday.id
                }
            }
        }

        XCTAssertEqual(mondayByOffset[0], "2026-05-11")
        let offsets = mondayByOffset.keys.sorted()
        guard let first = offsets.first, let last = offsets.last else {
            return XCTFail("No weeks built")
        }
        XCTAssertEqual(last - first + 1, offsets.count,
                       "Offsets must be gapless: \(first)...\(last)")
    }

    func testSyncDisplayedMonthToScrolledID() {
        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        viewModel.syncDisplayedMonth(toID: "2026-11")
        XCTAssertEqual(viewModel.displayedMonth?.id, "2026-11")
        viewModel.syncDisplayedMonth(toID: "not-a-month")
        XCTAssertEqual(viewModel.displayedMonth?.id, "2026-11",
                       "Unknown ids must be ignored")
    }
}
