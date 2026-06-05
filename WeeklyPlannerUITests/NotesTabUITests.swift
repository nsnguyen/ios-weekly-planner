import XCTest

final class NotesTabUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCreateNotePersistsAcrossRelaunchAndDeletes() {
        let app = XCUIApplication()
        app.launch()

        let notesTab = app.buttons["tabbar.tab.notes"]
        XCTAssertTrue(notesTab.waitForExistence(timeout: 5), "Notes tab missing from tab bar")
        notesTab.tap()

        let addRow = app.buttons["notes.addRow"]
        XCTAssertTrue(addRow.waitForExistence(timeout: 3))
        addRow.tap()

        let title = "UITest Note \(UUID().uuidString.prefix(6))"
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        titleField.typeText(String(title))

        app.buttons["notes.editor.done"].tap()

        // Build a fresh predicate at each call site: NSPredicate is not
        // Sendable, so under Swift 6 `complete` concurrency a single value
        // reused across the relaunch boundary trips "sending risks data
        // races". Constructing locally keeps each use self-contained.
        let titleString = String(title)
        func matchingTitle() -> XCUIElement {
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", titleString))
                .firstMatch
        }

        let row = matchingTitle()
        XCTAssertTrue(row.waitForExistence(timeout: 5), "New note row not visible after Done")

        // Relaunch — the note must persist (and lastTab restores Notes).
        app.terminate()
        app.launch()
        let notesTabAgain = app.buttons["tabbar.tab.notes"]
        if notesTabAgain.waitForExistence(timeout: 5) { notesTabAgain.tap() }
        let rowAfterRelaunch = matchingTitle()
        XCTAssertTrue(rowAfterRelaunch.waitForExistence(timeout: 5), "Note did not survive relaunch")

        // Cleanup: open and delete via the editor.
        rowAfterRelaunch.tap()
        let delete = app.buttons["notes.editor.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertTrue(rowAfterRelaunch.waitForNonExistence(timeout: 5), "Deleted note still visible")
    }
}
