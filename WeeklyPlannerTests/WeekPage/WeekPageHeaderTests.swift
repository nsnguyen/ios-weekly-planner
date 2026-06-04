import XCTest
@testable import WeeklyPlanner

/// Phase 30 tweaks (29) + (30): the week header drops the "N events" /
/// "M tasks left" count lines and the "Week NN" label; the date range is
/// the single enlarged title. The title is exposed as a testable static
/// (no view-introspection dependency in this codebase — same pattern as
/// `DayPageHeaderTests`).
@MainActor
final class WeekPageHeaderTests: XCTestCase {
    /// Saturday May 16, 2026 at noon — the standard planner test anchor.
    private static let anchor: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 16; c.hour = 12
        return WeekMath.mondayCalendar().date(from: c) ?? Date()
    }()

    private func sampleMeta() -> WeekMeta {
        WeekMath.weekMeta(forOffset: 0, today: Self.anchor)
    }

    func testTitleHasNoWeekLabel() {
        let title = WeekPageHeader.title(weekMeta: sampleMeta(), year: 2026)
        XCTAssertFalse(title.contains("Week"),
                       "Phase 30 (30): the 'Week NN' label must be removed")
    }

    func testTitleIsDateRangeWithYear() {
        let meta = sampleMeta()
        let title = WeekPageHeader.title(weekMeta: meta, year: 2026)
        XCTAssertTrue(title.contains(meta.range), "date range is the title")
        XCTAssertTrue(title.contains("2026"), "year retained")
    }

    func testHeaderHasNoCountLines() {
        // Compile-time pin: the initializer no longer accepts counts. If
        // someone re-adds eventCount/openTaskCount parameters, this fails
        // to build — exactly the regression Phase 30 (29) forbids.
        _ = WeekPageHeader(weekMeta: sampleMeta(), year: 2026)

        let title = WeekPageHeader.title(weekMeta: sampleMeta(), year: 2026)
        XCTAssertFalse(title.lowercased().contains("events"),
                       "Phase 30 (29): no 'N events' line")
        XCTAssertFalse(title.lowercased().contains("tasks left"),
                       "Phase 30 (29): no 'M tasks left' line")
    }
}
