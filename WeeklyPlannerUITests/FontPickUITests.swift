import XCTest

final class FontPickUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testPickingANewFontPersistsAcrossRelaunch() {
        let app = XCUIApplication()
        app.launch()

        let settingsTab = app.buttons["tabbar.tab.settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        // FontCard exposes accessibilityIdentifier "settings.font.card.<rawValue>"
        // (see AccessibilityIDs.settingsFontCard) plus the family display name
        // as both its label and a child static text.
        let patrick = app.buttons["settings.font.card.patrick"]
        XCTAssertTrue(patrick.waitForExistence(timeout: 5), "New font card not rendered")
        // Sanity-check the new family's display name is on screen.
        XCTAssertTrue(app.staticTexts["Patrick Hand"].firstMatch.waitForExistence(timeout: 2),
                      "Patrick Hand label not rendered on its card")
        patrick.tap()

        app.terminate()
        app.launch()
        let settingsAgain = app.buttons["tabbar.tab.settings"]
        if settingsAgain.waitForExistence(timeout: 5) { settingsAgain.tap() }

        // The card should still exist and remain the selected one. FontCard
        // adds the `.isSelected` trait when active, which XCUIElement exposes
        // via `isSelected` — so we can assert the choice survived relaunch.
        let patrickAgain = app.buttons["settings.font.card.patrick"]
        XCTAssertTrue(patrickAgain.waitForExistence(timeout: 5), "Font choice card missing after relaunch")
        XCTAssertTrue(patrickAgain.isSelected, "Font choice did not survive relaunch")
    }
}
