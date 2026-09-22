import XCTest

final class WeekStartUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testSwitchingWeekStartToSundayRelaysWeekPage() {
        let app = XCUIApplication()
        app.launch()

        // Settings → Week starts on → Sunday.
        let settingsTab = app.buttons["tabbar.tab.settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let menu = revealWeekStartMenu(in: app)
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "Week-start menu missing")
        menu.tap()
        let sunday = app.buttons["Sunday"]
        XCTAssertTrue(sunday.waitForExistence(timeout: 3))
        sunday.tap()

        // Calendar → Week view: Sunday's row must now sit above Monday's.
        app.buttons["tabbar.tab.calendar"].tap()
        let weekSeg = app.buttons["topbar.dayweek.week"]
        XCTAssertTrue(weekSeg.waitForExistence(timeout: 5))
        weekSeg.tap()

        let sunRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Sunday'")).firstMatch
        let monRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Monday'")).firstMatch
        XCTAssertTrue(sunRow.waitForExistence(timeout: 5), "No Sunday row on the week page")
        XCTAssertTrue(monRow.waitForExistence(timeout: 5), "No Monday row on the week page")
        XCTAssertLessThan(sunRow.frame.minY, monRow.frame.minY,
                          "Sunday must lead the week after the switch")

        // Restore Monday (leave the simulator clean for other suites).
        app.buttons["tabbar.tab.settings"].tap()
        let menuAgain = revealWeekStartMenu(in: app)
        menuAgain.tap()
        let monday = app.buttons["Monday"]
        XCTAssertTrue(monday.waitForExistence(timeout: 3))
        monday.tap()
    }

    /// Preferences sit below the fold once fonts and connections are on the page.
    private func revealWeekStartMenu(in app: XCUIApplication) -> XCUIElement {
        let menu = app.buttons["settings.weekstart.menu"]
        if menu.waitForExistence(timeout: 2) {
            return menu
        }
        for _ in 0 ..< 4 {
            app.swipeUp()
            if menu.waitForExistence(timeout: 1) {
                return menu
            }
        }
        return menu
    }
}
