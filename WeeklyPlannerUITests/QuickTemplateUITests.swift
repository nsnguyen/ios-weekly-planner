import XCTest

final class QuickTemplateUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testGymChipPrefillsAndSaves() {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSeedEmptyStore"]
        app.launch()

        let calendarTab = app.buttons["tabbar.tab.calendar"]
        if calendarTab.waitForExistence(timeout: 3) { calendarTab.tap() }

        let addLink = app.buttons["daypage.events.addRow"]
        XCTAssertTrue(addLink.waitForExistence(timeout: 5))
        addLink.tap()

        let gymChip = app.buttons["paperEventSheet.template.gym"]
        XCTAssertTrue(gymChip.waitForExistence(timeout: 3), "Template chips missing from create sheet")
        gymChip.tap()

        // Title got pre-filled.
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        XCTAssertEqual(titleField.value as? String, "Gym")

        // The chip pre-fill does not raise the keyboard, but guard against it
        // obscuring the header Save button just in case focus moved.
        if app.keyboards.firstMatch.exists {
            app.keyboards.buttons["Return"].tap()
            _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 2)
        }

        let save = app.buttons["paperEventSheet.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 2))
        save.tap()
        _ = save.waitForNonExistence(timeout: 5)

        let predicate = NSPredicate(format: "label CONTAINS %@", "Gym")
        XCTAssertTrue(app.descendants(matching: .any).matching(predicate).firstMatch
            .waitForExistence(timeout: 5), "Templated event not visible after save")
    }
}
