import XCTest

final class SmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Sanity check: the app launches into the foreground and presents at
    /// least one window within five seconds. We don't assert on any specific
    /// text because the Day page now renders dynamic seed content — the
    /// visible strings change by date / locale.
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5),
                      "Application window did not appear within 5 seconds")
    }
}
