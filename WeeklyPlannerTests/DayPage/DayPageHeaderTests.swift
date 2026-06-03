import XCTest
@testable import WeeklyPlanner

/// Phase 29 tweak (9): the "· Week NN" suffix under the day-of-week is gone;
/// the caption is just "<day> <month>". The caption is exposed as a testable
/// static (no view-introspection dependency in this codebase).
@MainActor
final class DayPageHeaderTests: XCTestCase {
    private func sampleDay() -> WeekDay {
        // Saturday May 16, 2026 — the standard planner anchor.
        let week = WeekMath.weekDays(forOffset: 0, today: DayPageHeaderTests.anchor)
        return week.first { $0.idx == 5 } ?? week[0]
    }

    func testCaptionHasNoWeekLabel() {
        let caption = DayPageHeader.caption(for: sampleDay())
        XCTAssertFalse(caption.contains("Week"),
                       "Phase 29 (9): the 'Week NN' line must be removed")
        XCTAssertFalse(caption.contains("·"),
                       "the day·month separator that joined the week label should be gone too")
    }

    func testCaptionStillShowsDayAndMonth() {
        let day = sampleDay()
        let caption = DayPageHeader.caption(for: day)
        XCTAssertTrue(caption.contains("\(day.dayNumber)"), "day number retained")
        XCTAssertTrue(caption.contains(day.monthShort), "month retained")
    }

    private static let anchor: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 16; c.hour = 12
        return WeekMath.mondayCalendar().date(from: c) ?? Date()
    }()
}
