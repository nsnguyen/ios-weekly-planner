import SwiftUI
import XCTest
@testable import WeeklyPlanner

/// Phase 31 (33)(34) presentation contracts for the month grid. The suite
/// has no snapshot infrastructure, so these pin the constants/helpers the
/// view bodies consume rather than rendered pixels; the screenshot diff vs
/// `docs/mock/` is the visual gate.
@MainActor
final class MonthGridViewTests: XCTestCase {
    /// Reference date used throughout the suite: Saturday, May 16, 2026.
    private static func may16_2026() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = 12
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }

    /// (34) The "May 2026" title is centered in the section header.
    func testTitleCentered() {
        XCTAssertEqual(MonthGridView.titleAlignment, .center)
    }

    /// (33) Monday-first weekday header, all seven days — weekends stay.
    func testWeekdayHeaderPresent() {
        XCTAssertEqual(MonthGridView.weekdaySymbols,
                       ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"])
    }

    /// (33) The ISO week-number column is gone from rows, the row's
    /// accessibility label no longer leaks the ISO number, and the removal
    /// is presentation-only (`PickerWeek.weekNumber` survives in the model).
    func testNoWeekNumberRendered() {
        XCTAssertFalse(WeekRowView.showsWeekNumberColumn)

        let viewModel = WeekPickerViewModel(baseDate: Self.may16_2026(), focusWeekOffset: 0)
        let currentWeek = viewModel.months
            .flatMap(\.weeks)
            .first { $0.offset == 0 }
        XCTAssertNotNil(currentWeek)
        guard let currentWeek else { return }

        // Presentation-only: the model still carries the ISO number…
        XCTAssertEqual(currentWeek.weekNumber, 20)
        // …but the row's VoiceOver label is date-based, not "Week 20".
        let label = WeekRowView.accessibilityLabel(for: currentWeek)
        XCTAssertEqual(label, "Week of May 11")
        XCTAssertFalse(label.contains("\(currentWeek.weekNumber)"))
    }
}
