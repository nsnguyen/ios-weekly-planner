import XCTest
@testable import WeeklyPlanner

/// Phase 30 tweaks (25), (26), (28): the week row is events-only, empties
/// read "none", and event-heavy days split into two columns capped with a
/// "+K more" affordance instead of clipping. The layout decision is a pure
/// value type (`WeekDayRowLayout`) so the rule is pinned without view
/// introspection (codebase convention — see `DayPageHeaderTests`).
@MainActor
final class WeekDayRowTests: XCTestCase {
    /// Saturday May 16, 2026 at noon — the standard planner test anchor.
    private static let anchor: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 16; c.hour = 12
        return WeekMath.mondayCalendar().date(from: c) ?? Date()
    }()

    /// `count` back-to-back one-hour events starting at the anchor, titled
    /// "Event 0"…"Event N-1" so column ordering is assertable.
    private func makeEvents(_ count: Int) -> [Event] {
        let calendar = WeekMath.mondayCalendar()
        return (0..<count).map { i in
            let start = calendar.date(byAdding: .hour, value: i, to: Self.anchor) ?? Self.anchor
            let end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start
            return Event(title: "Event \(i)", start: start, end: end, category: .work)
        }
    }

    private func saturday() -> WeekDay {
        let days = WeekMath.weekDays(forOffset: 0, today: Self.anchor)
        return days.first { $0.idx == 5 } ?? days[0]
    }

    // MARK: - (28) empty day

    func testEmptyDayPlaceholderReadsNone() {
        XCTAssertEqual(WeekDayRow.emptyPlaceholder, "none",
                       "Phase 30 (28): empty days read 'none', not '—'")
        XCTAssertTrue(WeekDayRowLayout.compute(for: []).isEmpty)
    }

    // MARK: - (26) events-only

    func testTaskBearingDayRendersNoTaskRows() {
        // Compile-time pin: WeekDayRow no longer accepts tasks or a toggle
        // callback — a task-bearing day cannot render task rows because the
        // row has no channel for them (Phase 30, #26; events-only is the
        // permanent week-page default).
        _ = WeekDayRow(day: saturday(), events: makeEvents(1), isToday: false)

        // And a day whose only content is tasks lays out as empty → "none";
        // tasks have no influence on the week-row layout at all.
        XCTAssertTrue(WeekDayRowLayout.compute(for: []).isEmpty,
                      "tasks must not influence the week row layout")
    }

    // MARK: - (25) layout rule: 1–3 events stay single column

    func testUpToThreeEventsStaySingleColumn() {
        for n in 1...3 {
            let layout = WeekDayRowLayout.compute(for: makeEvents(n))
            XCTAssertEqual(layout.leftColumn.count, n, "n=\(n) all in left column")
            XCTAssertTrue(layout.rightColumn.isEmpty, "n=\(n) is single column")
            XCTAssertEqual(layout.overflowCount, 0, "n=\(n) no overflow")
        }
    }

    // MARK: - (25) layout rule: 4–6 events split two columns, column-major

    func testFourToSixEventsSplitTwoColumnsColumnMajor() {
        let expected: [(n: Int, left: Int, right: Int)] = [(4, 2, 2), (5, 3, 2), (6, 3, 3)]
        for c in expected {
            let layout = WeekDayRowLayout.compute(for: makeEvents(c.n))
            XCTAssertEqual(layout.leftColumn.count, c.left, "n=\(c.n) left column")
            XCTAssertEqual(layout.rightColumn.count, c.right, "n=\(c.n) right column")
            XCTAssertEqual(layout.overflowCount, 0, "n=\(c.n) no overflow")
        }
        // Column-major: chronological order reads down the left column,
        // then down the right.
        let layout = WeekDayRowLayout.compute(for: makeEvents(5))
        XCTAssertEqual(layout.leftColumn.map(\.title), ["Event 0", "Event 1", "Event 2"])
        XCTAssertEqual(layout.rightColumn.map(\.title), ["Event 3", "Event 4"])
    }

    // MARK: - (25) layout rule: 7+ events cap at 5 visible + overflow

    func testEventHeavyDayCapsRowsAndShowsOverflow() {
        let layout = WeekDayRowLayout.compute(for: makeEvents(7))
        XCTAssertEqual(layout.leftColumn.count, 3)
        XCTAssertEqual(layout.rightColumn.count, 2)
        XCTAssertEqual(layout.overflowCount, 2, "7 events → 5 visible + '+2 more'")

        let heavy = WeekDayRowLayout.compute(for: makeEvents(12))
        XCTAssertEqual(heavy.leftColumn.count + heavy.rightColumn.count, 5,
                       "visible events cap at 5 when overflowing")
        XCTAssertEqual(heavy.overflowCount, 7)
    }

    func testOverflowLabel() {
        XCTAssertEqual(WeekDayRowLayout.overflowLabel(2), "+2 more")
        XCTAssertEqual(WeekDayRowLayout.overflowLabel(7), "+7 more")
    }
}
