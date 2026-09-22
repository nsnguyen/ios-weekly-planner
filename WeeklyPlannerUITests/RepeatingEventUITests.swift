import XCTest

final class RepeatingEventUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testDailyEventAppearsOnAdjacentDayAndScopedDeleteWorks() {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSeedEmptyStore"]
        app.launch()

        let calendarTab = app.buttons["tabbar.tab.calendar"]
        if calendarTab.waitForExistence(timeout: 3) {
            calendarTab.tap()
        }
        let daySeg = app.buttons["topbar.dayweek.day"]
        if daySeg.waitForExistence(timeout: 3) {
            daySeg.tap()
        }

        // Create a daily event.
        let addLink = app.buttons["daypage.events.addRow"]
        XCTAssertTrue(addLink.waitForExistence(timeout: 5))
        addLink.tap()

        let title = "UITest Daily \(UUID().uuidString.prefix(6))"
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        chooseDailyRepeat(app, title: String(title), field: titleField)

        let save = app.buttons["paperEventSheet.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 2))
        save.tap()
        _ = save.waitForNonExistence(timeout: 5)

        // Build the matcher fresh at each call site: a single shared
        // `NSPredicate` instance can't cross Swift 6 concurrency boundaries.
        let titleString = String(title)
        func eventElement() -> XCUIElement {
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", titleString))
                .firstMatch
        }

        XCTAssertTrue(eventElement().waitForExistence(timeout: 5),
                      "Event missing on its creation day")

        // Navigate to an ADJACENT day in the same week via side tabs:
        // pick any side tab that isn't the currently-selected day.
        var adjacentFound = false
        for index in 0 ..< 7 {
            let tab = app.buttons["daypage.sidetab.\(index)"]
            guard tab.waitForExistence(timeout: 1), tab.isHittable else { continue }
            tab.tap()
            if eventElement().waitForExistence(timeout: 3) {
                adjacentFound = true
                break
            }
        }
        XCTAssertTrue(adjacentFound, "Daily event not found on any other day of the week")

        // Open the occurrence → delete ALL occurrences via the dialog.
        eventElement().tap()
        // Trigger delete from the sheet (read → edit → delete, or direct
        // delete affordance — follow the existing EventCreateFlow test's path).
        let deleteButton = app.buttons["Delete event"]
        if !deleteButton.waitForExistence(timeout: 3) {
            // Sheet may need edit mode for the delete affordance.
            let edit = app.buttons["paperEventSheet.edit"]
            if edit.waitForExistence(timeout: 2) {
                edit.tap()
            }
        }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.tap()

        let deleteAll = app.buttons["Delete all occurrences"]
        XCTAssertTrue(deleteAll.waitForExistence(timeout: 3),
                      "Scoped-delete dialog did not appear for a repeating event")
        deleteAll.tap()

        XCTAssertTrue(eventElement().waitForNonExistence(timeout: 5),
                      "Series not removed after delete-all")
    }
}

/// Types the title, resigns the field, and picks Daily.
///
/// A newline typed into the single-line title field does not resign it.
/// The following tap is then consumed dismissing the keyboard, so the
/// Repeat menu never opens. The Return key does resign it (same path as
/// the event-create UI test). If that tap is still swallowed, try once more.
@MainActor
private func chooseDailyRepeat(_ app: XCUIApplication, title: String, field: XCUIElement) {
    _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
    field.typeText(title)
    if app.keyboards.firstMatch.exists {
        app.keyboards.buttons["Return"].tap()
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 2)
    }

    let repeatMenu = app.buttons["paperEventSheet.repeat"]
    XCTAssertTrue(repeatMenu.waitForExistence(timeout: 3), "Repeat menu missing")
    // The sheet is not a scroll view. element.tap() asks the button to
    // scroll on screen, that action fails, and the hit point stays {-1, -1}
    // even though the control's frame is inside the window.
    tapWindowPoint(of: repeatMenu, in: app)
    let daily = app.buttons["Daily"]
    if !daily.waitForExistence(timeout: 2) {
        tapWindowPoint(of: repeatMenu, in: app)
    }
    XCTAssertTrue(daily.waitForExistence(timeout: 3), "Repeat menu did not open")
    daily.tap()
}

/// Taps the element's window frame. Skips the scroll-to-visible path that
/// `XCUIElement.tap()` takes for a control the sheet cannot scroll.
@MainActor
private func tapWindowPoint(of element: XCUIElement, in app: XCUIApplication) {
    let frame = element.frame
    app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
        .tap()
}
