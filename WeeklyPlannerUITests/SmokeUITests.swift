import XCTest

final class SmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()

        let banner = app.staticTexts["Phase 05 — Paper book chrome ready"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5),
                      "Paper-book placeholder text did not appear within 5 seconds")
    }
}
