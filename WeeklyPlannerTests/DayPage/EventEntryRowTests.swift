import Foundation
import XCTest
@testable import WeeklyPlanner

/// Time-formatting rules for `EventEntryRow.timeLabel(for:)`. Layout/visual
/// behavior is exercised via SwiftUI previews and snapshot tests in later
/// groups; this suite isolates the pure string logic.
final class EventEntryRowTests: XCTestCase {
    // MARK: - Hour-only formatting (minute == 0)

    func testTimeFormattingHourOnly() {
        XCTAssertEqual(EventEntryRow.timeLabel(for: time(hour: 9)), "9 AM")
        XCTAssertEqual(EventEntryRow.timeLabel(for: time(hour: 13)), "1 PM")
        XCTAssertEqual(EventEntryRow.timeLabel(for: time(hour: 12)), "12 PM")
        XCTAssertEqual(EventEntryRow.timeLabel(for: time(hour: 0)), "12 AM")
    }

    // MARK: - Hour + minute formatting

    func testTimeFormattingWithMinutes() {
        XCTAssertEqual(EventEntryRow.timeLabel(for: time(hour: 7, minute: 45)), "7:45 AM")
        XCTAssertEqual(EventEntryRow.timeLabel(for: time(hour: 13, minute: 30)), "1:30 PM")
        XCTAssertEqual(EventEntryRow.timeLabel(for: time(hour: 12, minute: 30)), "12:30 PM")
    }

    // MARK: - Helpers

    /// Constructs a `Date` at the given `hour:minute` on the Saturday-May-16
    /// anchor used across the planner test suite. Going through
    /// `WeekMath.mondayCalendar()` keeps timezone math deterministic.
    private func time(hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        components.minute = minute
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
