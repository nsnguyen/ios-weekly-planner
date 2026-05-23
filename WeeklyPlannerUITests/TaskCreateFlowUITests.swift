import XCTest

/// End-to-end inline add-task flow: launch app → tap the always-visible
/// `+ add a to-do` / `+ add your first to-do` row inside the bottom-pinned
/// `TodoBlock` → type title → Return → verify the row appears.
///
/// The to-do patch is now always rendered (the `EmptyDayState` empty-day
/// CTA was retired when the patch became persistent), so a single
/// identifier lookup (`daypage.todo.addRow`) covers both empty and
/// non-empty states.
final class TaskCreateFlowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testAddTaskInline_endToEnd() throws {
        let app = XCUIApplication()
        app.launch()

        let addRow = app.buttons["daypage.todo.addRow"]
        XCTAssertTrue(addRow.waitForExistence(timeout: 5),
                      "TodoBlock add row should be reachable on the landing day")
        addRow.tap()

        // Type a unique title so we can find the row deterministically.
        let title = "UITest Prep \(UUID().uuidString.prefix(6))"
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(String(title))
        // The TextField uses .submitLabel(.done), so the Return key is
        // labeled "done" in the keyboard. Tapping it commits via the
        // .onSubmit handler.
        app.keyboards.buttons["done"].tap()

        // The new row carries the title in its accessibility label
        // (via `accessibleTask(...)` from Phase 21). Wait for it.
        let predicate = NSPredicate(format: "label CONTAINS %@", String(title))
        let result = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5),
                      "New task title should be visible on the Day page after Return")
    }
}
