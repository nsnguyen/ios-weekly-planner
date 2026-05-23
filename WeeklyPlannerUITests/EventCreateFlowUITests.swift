import XCTest

/// End-to-end create-event flow: launch app → tap the inline
/// "+ add an event" link at the bottom of the Day page → fill title →
/// tap Save → verify a row labeled with that title appears on the Day
/// page.
final class EventCreateFlowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCreateEvent_endToEnd() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSeedEmptyStore"]
        app.launch()

        // TabSelection is persisted across launches — explicitly land
        // on the Calendar tab before looking for Day-page identifiers.
        let calendarTab = app.buttons["tabbar.tab.calendar"]
        if calendarTab.waitForExistence(timeout: 3) {
            calendarTab.tap()
        }

        // The "+ add another" / "+ add your first event" inline link
        // lives below the events + inbox list on the Day page — always
        // present regardless of empty-state.
        let addLink = app.buttons["daypage.events.addRow"]
        XCTAssertTrue(addLink.waitForExistence(timeout: 5))
        addLink.tap()

        let title = "UITest Lunch \(UUID().uuidString.prefix(6))"
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        // Give the keyboard a beat to attach focus before typing — without
        // this, `typeText` occasionally fires before the field's
        // `@FocusState` flips and the keystrokes drop, leaving the title
        // empty and `Save` disabled.
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        titleField.typeText(String(title))

        // Sanity-check that the field actually accepted the keystrokes.
        // If this fails, Save will be disabled and the rest of the test
        // can't pass — better to surface the typing failure directly.
        XCTAssertEqual(titleField.value as? String, String(title),
                       "Title field did not capture the typed text — focus/keyboard timing likely off")

        // Dismiss the on-screen keyboard so it doesn't obscure the Save
        // button in the sheet's header bar. Without this, `Save` ends up
        // beneath the keyboard chrome and XCUIElement.tap() computes an
        // invalid hit point ({-1, -1}) so the tap never lands.
        if app.keyboards.firstMatch.exists {
            // "return" on a SwiftUI TextField resigns first responder.
            app.keyboards.buttons["Return"].tap()
            _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 2)
        }

        let save = app.buttons["paperEventSheet.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 2))
        XCTAssertTrue(save.isEnabled, "Save button should be enabled after a valid title is typed")
        save.tap()

        // Give the async `viewModel.save()` time to complete, then the
        // sheet's `isOpen = false` to flip and the dismissal animation to
        // settle.
        _ = save.waitForNonExistence(timeout: 5)

        // Auto-refresh on .eventStoreDidChange should make the row visible
        // without manual intervention, but we keep a short pull-to-refresh
        // here as a fallback for simulator timing flakes (notification → Task
        // → SwiftUI re-render can lag a few frames).
        let firstWindow = app.windows.firstMatch
        let start = firstWindow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        let finish = firstWindow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.1, thenDragTo: finish)

        // Day-page rows collapse into a single combined accessibility element
        // (see `accessibleEvent` in AccessibilityModifiers.swift) with
        // `.isButton` trait — so the new title surfaces as a `button` label,
        // not a `staticText`. Search across any descendant type to be robust.
        let predicate = NSPredicate(format: "label CONTAINS %@",
                                    String(title))
        let result = app.descendants(matching: .any)
            .matching(predicate)
            .firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5),
                      "New event title should be visible on the Day page after save")
    }
}
