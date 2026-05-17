import XCTest

final class SmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()

        let banner = app.staticTexts["Weekly Planner — bootstrap"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5),
                      "Bootstrap placeholder text did not appear within 5 seconds")
    }
}
