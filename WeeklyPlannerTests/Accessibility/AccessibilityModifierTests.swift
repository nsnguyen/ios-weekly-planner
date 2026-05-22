import Foundation
import XCTest
@testable import WeeklyPlanner

// AccessibilityFormatters are pure functions that read model fields —
// no ModelContainer needed even though Event/TaskItem are @Model classes.
@MainActor
final class AccessibilityModifierTests: XCTestCase {

    // MARK: - eventLabel

    func testEventLabel_includesAllFields() {
        let event = makeEvent(title: "Sara's birthday",
                              category: WeeklyPlanner.Category.personal,
                              location: "Maison's",
                              source: WeeklyPlanner.EventSource.manual)
        let label = AccessibilityFormatters.eventLabel(event)
        XCTAssertTrue(label.contains("Sara's birthday"), "label missing title: \(label)")
        XCTAssertTrue(label.contains("Personal"),        "label missing category: \(label)")
        XCTAssertTrue(label.contains("Maison's"),        "label missing location: \(label)")
        XCTAssertTrue(label.contains("added by you"),    "label missing source: \(label)")
    }

    func testEventLabel_noLocation_saysNoLocation() {
        let event = makeEvent(title: "Phone call",
                              category: WeeklyPlanner.Category.work,
                              location: nil,
                              source: WeeklyPlanner.EventSource.manual)
        let label = AccessibilityFormatters.eventLabel(event)
        XCTAssertTrue(label.contains("no location"), "label should say 'no location': \(label)")
    }

    func testEventLabel_gmailSource_saysFromGmail() {
        let event = makeEvent(title: "Resy reservation",
                              category: WeeklyPlanner.Category.personal,
                              location: "Casa Mono",
                              source: WeeklyPlanner.EventSource.gmail)
        let label = AccessibilityFormatters.eventLabel(event)
        XCTAssertTrue(label.contains("from Gmail"), "label should say 'from Gmail': \(label)")
    }

    // MARK: - taskLabel

    func testTaskLabel_completedFlag() {
        let doneTask = makeTask(title: "Buy milk", done: true)
        let openTask = makeTask(title: "Buy milk", done: false)
        let doneLabel = AccessibilityFormatters.taskLabel(doneTask)
        let openLabel = AccessibilityFormatters.taskLabel(openTask)
        XCTAssertTrue(doneLabel.contains("completed"),     "done label wrong: \(doneLabel)")
        XCTAssertTrue(openLabel.contains("not completed"), "open label wrong: \(openLabel)")
    }

    // MARK: - sideTabLabel

    func testSideTabLabel_includesDayPosition() {
        let label = AccessibilityFormatters.sideTabLabel(weekdayFull: "Wednesday", dayN: 3)
        XCTAssertTrue(label.contains("Wednesday"), "label missing weekday: \(label)")
        XCTAssertTrue(label.contains("day 3 of 7"), "label missing day position: \(label)")
    }

    // MARK: - weekRowLabel

    func testWeekRowLabel_includesWeekNumber() {
        let label = AccessibilityFormatters.weekRowLabel(range: "Mar 4 – Mar 10", weekNumber: 10)
        XCTAssertTrue(label.contains("Mar 4 – Mar 10"), "label missing range: \(label)")
        XCTAssertTrue(label.contains("week 10"),        "label missing week number: \(label)")
    }

    // MARK: - Helpers

    /// Build a minimal Event. All non-exercised fields use their defaults.
    /// EventSource has .manual (not .user) — adapt the caller's `.user` tests
    /// to `.manual` (same semantic: not from an external source).
    private func makeEvent(title: String,
                           category: WeeklyPlanner.Category,
                           location: String?,
                           source: WeeklyPlanner.EventSource) -> Event {
        Event(title: title,
              start: Date(),
              end: Date(timeIntervalSinceNow: 3600),
              location: location,
              category: category,
              source: source)
    }

    /// Build a minimal TaskItem. `done` defaults to false in the model init,
    /// so we set it explicitly after construction.
    private func makeTask(title: String, done: Bool) -> TaskItem {
        let task = TaskItem(title: title, due: Date(), category: WeeklyPlanner.Category.personal)
        task.done = done
        return task
    }
}
