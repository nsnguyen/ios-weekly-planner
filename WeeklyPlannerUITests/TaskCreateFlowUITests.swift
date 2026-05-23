import XCTest

/// End-to-end inline add-task flow: launch app → find or open TodoBlock
/// → tap "+ add a task" → type title → Return → verify the row appears.
///
/// Mirrors Phase 22's `EventCreateFlowUITests` discovery pattern; uses
/// the `daypage.todo.addRow` identifier from `TodoAddRow` and falls back
/// to `daypage.empty.addTask` from `EmptyDayState` when the day starts
/// empty.
final class TaskCreateFlowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testAddTaskInline_endToEnd() throws {
        let app = XCUIApplication()
        app.launch()

        // Open the composer. The Day page may already render a TodoBlock
        // (from seeded tasks) — if so, tap its add row directly. Otherwise
        // tap the empty-state CTA.
        let addRow = app.buttons["daypage.todo.addRow"]
        let emptyCTA = app.buttons["daypage.empty.addTask"]

        // The simulator's SwiftData store persists across test runs, so the
        // landing day (today) accumulates events from `EventCreateFlowUITests`
        // and shows neither TodoBlock (no tasks) nor EmptyDayState (has
        // events). Hop the sidetab carousel to find a day where one of the
        // two CTAs is reachable. Sidetabs are stable identifiers
        // `daypage.sidetab.{0..6}` set by Phase 06's DayPageView.
        func findComposerEntry() -> Bool {
            if addRow.waitForExistence(timeout: 2) { addRow.tap(); return true }
            if emptyCTA.waitForExistence(timeout: 1) { emptyCTA.tap(); return true }
            for idx in 0...6 {
                let tab = app.buttons["daypage.sidetab.\(idx)"]
                guard tab.exists else { continue }
                tab.tap()
                if addRow.waitForExistence(timeout: 1) { addRow.tap(); return true }
                if emptyCTA.waitForExistence(timeout: 1) { emptyCTA.tap(); return true }
            }
            return false
        }
        let opened = findComposerEntry()
        XCTAssertTrue(opened, "Either the TodoBlock add row or the empty-state CTA should be reachable on some weekday")

        // Type a unique title so we can find the row deterministically.
        let title = "UITest Prep \(UUID().uuidString.prefix(6))"
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(String(title))
        // Return commits.
        app.keyboards.buttons["return"].tap()

        // The new row carries the title in its accessibility label
        // (via `accessibleTask(...)` from Phase 21). Wait for it.
        let predicate = NSPredicate(format: "label CONTAINS %@", String(title))
        let result = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5),
                      "New task title should be visible on the Day page after Return")
    }
}
