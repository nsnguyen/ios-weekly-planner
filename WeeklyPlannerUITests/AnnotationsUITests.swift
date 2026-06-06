import XCTest

/// Phase 34 — Free-Text Annotations.
///
/// `-UITestSeedEmptyStore` is passed for sibling-suite parity but is NOT
/// honored by the app target, so the store persists across launches. The
/// tests therefore (1) run on Sunday's page (side tab 6), which stays
/// quiet on the shared simulator, (2) pre-clean any residue from earlier
/// failed runs, and (3) always delete what they create.
final class AnnotationsUITests: XCTestCase {
    private enum ID {
        static func dayWeekSegment(_ v: String) -> String { "topbar.dayweek.\(v)" }
        static func sideTab(_ n: Int) -> String { "daypage.sidetab.\(n)" }
        static let editor = "daypage.annotation.editor"
        static let styleDone = "annotation.style.done"
        static let styleBold = "annotation.style.bold"
        static let styleRed = "annotation.style.color.red"
        static let styleDelete = "annotation.style.delete"
    }

    /// The day cell the tests work on. Sunday — empty paper on the test sim.
    private static let testDayIdx = 6

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @MainActor
    private func launchOnTestDayPage() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSeedEmptyStore"]
        app.launch()
        navigateToTestDay(app)
        return app
    }

    /// Calendar tab → Day view → Sunday side tab. Idempotent.
    @MainActor
    private func navigateToTestDay(_ app: XCUIApplication) {
        let calendarTab = app.buttons["tabbar.tab.calendar"]
        if calendarTab.waitForExistence(timeout: 3) { calendarTab.tap() }
        let daySeg = app.buttons[ID.dayWeekSegment("day")]
        if daySeg.waitForExistence(timeout: 3) { daySeg.tap() }
        let sunday = app.buttons[ID.sideTab(Self.testDayIdx)]
        if sunday.waitForExistence(timeout: 3) { sunday.tap() }
    }

    /// Best-effort deletion of an annotation with the given text — used to
    /// pre-clean residue and to clean up after each test. Never asserts.
    @MainActor
    private func deleteAnnotationIfPresent(_ app: XCUIApplication, text: String) {
        let annotation = app.staticTexts[text]
        guard annotation.waitForExistence(timeout: 2) else { return }
        annotation.tap()
        let delete = app.buttons[ID.styleDelete]
        if delete.waitForExistence(timeout: 3) {
            delete.tap()
            _ = annotation.waitForNonExistence(timeout: 4)
        }
    }

    /// Sweep empty-text ghost annotations (display label "Annotation: ") left
    /// on the shared simulator by earlier runs. Best-effort, never asserts.
    @MainActor
    private func purgeGhostAnnotations(_ app: XCUIApplication) {
        for _ in 0..<12 {
            let ghost = app.buttons.matching(NSPredicate(format: "label == %@", "Annotation: ")).firstMatch
            guard ghost.exists else { return }
            ghost.tap()
            let delete = app.buttons[ID.styleDelete]
            guard delete.waitForExistence(timeout: 2) else { return }
            delete.tap()
            usleep(300_000) // let the layer settle before the next sweep
        }
    }

    /// Long-press empty paper until the annotation editor appears, then type
    /// `text`. Retries a few candidate spots: a press that lands on a row is
    /// swallowed by the row's context menu (rows use `.contextMenu`), so a
    /// neutral tap dismisses whatever came up before the next attempt.
    @MainActor
    private func createAnnotation(in app: XCUIApplication, text: String) -> Bool {
        let paper = app.scrollViews.firstMatch
        guard paper.waitForExistence(timeout: 5) else { return false }
        let editor = app.textFields[ID.editor]
        let candidates: [CGVector] = [
            CGVector(dx: 0.55, dy: 0.55),
            CGVector(dx: 0.5, dy: 0.7),
            CGVector(dx: 0.6, dy: 0.45),
        ]
        for (attempt, offset) in candidates.enumerated() {
            paper.coordinate(withNormalizedOffset: offset).press(forDuration: 0.8)
            if editor.waitForExistence(timeout: 3) {
                _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
                app.typeText(text)
                return true
            }
            if attempt < candidates.count - 1 {
                // Dismiss a possible context menu; on empty paper this tap
                // is inert (plain taps never create annotations).
                paper.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.25)).tap()
            }
        }
        return false
    }

    // MARK: - Tests

    @MainActor
    func testLongPressCreatesStyledAnnotationThatPersists() {
        let app = launchOnTestDayPage()
        purgeGhostAnnotations(app)
        deleteAnnotationIfPresent(app, text: "call mom") // residue pre-clean

        XCTAssertTrue(createAnnotation(in: app, text: "call mom"),
                      "Annotation editor did not appear after long-press attempts")

        app.buttons[ID.styleRed].tap()
        app.buttons[ID.styleBold].tap()
        app.buttons[ID.styleDone].tap()

        let placed = app.staticTexts["call mom"]
        XCTAssertTrue(placed.waitForExistence(timeout: 4), "Committed annotation not rendered")

        // Relaunch — must persist on the same day.
        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launchArguments += ["-UITestSeedEmptyStore"]
        relaunched.launch()
        navigateToTestDay(relaunched)
        let after = relaunched.staticTexts["call mom"]
        XCTAssertTrue(after.waitForExistence(timeout: 6), "Annotation did not survive relaunch")

        // Cleanup (mandatory — the store is persistent).
        after.tap()
        let delete = relaunched.buttons[ID.styleDelete]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertTrue(after.waitForNonExistence(timeout: 4))
    }

    @MainActor
    func testAbortedAnnotationDragDoesNotLockNavigation() {
        let app = launchOnTestDayPage()
        purgeGhostAnnotations(app)
        deleteAnnotationIfPresent(app, text: "drag me") // residue pre-clean

        XCTAssertTrue(createAnnotation(in: app, text: "drag me"),
                      "Annotation editor did not appear after long-press attempts")
        app.buttons[ID.styleDone].tap()

        let annotation = app.staticTexts["drag me"]
        XCTAssertTrue(annotation.waitForExistence(timeout: 4))

        // Drag it a little and release — then navigation must still work
        // (Phase 28 contract: the gesture-state reset clears suppression).
        let start = annotation.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 60, dy: 25))
        start.press(forDuration: 0.1, thenDragTo: end)

        let friday = app.buttons[ID.sideTab(4)]
        XCTAssertTrue(friday.waitForExistence(timeout: 3), "Friday side tab not found")
        friday.tap()
        XCTAssertTrue(friday.isHittable, "Day navigation unresponsive after annotation drag")

        // Cleanup (best-effort, non-asserting): back to the test day, delete.
        navigateToTestDay(app)
        deleteAnnotationIfPresent(app, text: "drag me")
    }
}
