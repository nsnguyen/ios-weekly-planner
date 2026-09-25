import XCTest

final class TemplateEditorUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testAddAndDeleteCustomTemplateChip() {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSeedEmptyStore"]
        app.launch()

        let calendarTab = app.buttons["tabbar.tab.calendar"]
        if calendarTab.waitForExistence(timeout: 3) {
            calendarTab.tap()
        }

        let addRow = app.buttons["daypage.events.addRow"]
        XCTAssertTrue(addRow.waitForExistence(timeout: 5))
        addRow.tap()

        let editChip = app.buttons["paperEventSheet.templates.edit"]
        XCTAssertTrue(editChip.waitForExistence(timeout: 5))
        editChip.tap()

        let titleField = app.textFields["templateEditor.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("Swim")
        app.buttons["templateEditor.add"].tap()
        app.buttons["Done"].tap()

        let swim = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Swim"))
            .firstMatch
        XCTAssertTrue(swim.waitForExistence(timeout: 3),
                      "Custom chip must appear in the quick-add row")

        editChip.tap()
        let deleteButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'templateEditor.delete.'"))
        XCTAssertGreaterThan(deleteButtons.count, 0)
        deleteButtons.element(boundBy: deleteButtons.count - 1).tap()
        app.buttons["Done"].tap()
    }
}
