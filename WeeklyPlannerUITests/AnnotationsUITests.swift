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
        // Pin Dynamic Type: the stacking test's geometry assertion budgets
        // against the header's rendered height.
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
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

    /// Deletes every committed annotation on the current page (display
    /// label "Annotation: <text>"), regardless of text. The stacking test
    /// needs the WHOLE page empty: stacking correctly lands below any
    /// residue, so leftovers from aborted runs — even with texts no test
    /// claims — would read as placement failures. Generic by prefix so
    /// unknown residue self-heals. Best-effort, never asserts.
    @MainActor
    private func purgeAllAnnotations(_ app: XCUIApplication) {
        for _ in 0..<12 {
            let note = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", "Annotation: ")).firstMatch
            guard note.exists else { return }
            note.tap()
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
                // Dismiss a possible context menu with a bottom-trailing tap:
                // that corner is never occupied (notes hug the leading margin
                // and stack from the top), and plain taps never create
                // annotations.
                paper.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()
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

    @MainActor
    func testNewNotesStackFromTopOfEmptyDay() {
        let app = launchOnTestDayPage()
        purgeAllAnnotations(app) // whole page must be empty — see helper doc

        // First note: pressed mid-page, must land in the top third — the
        // press position is ignored and an empty day stacks from the top.
        XCTAssertTrue(createAnnotation(in: app, text: "stack one"),
                      "Annotation editor did not appear after long-press attempts")
        app.buttons[ID.styleDone].tap()

        let paper = app.scrollViews.firstMatch
        let first = app.staticTexts["stack one"]
        XCTAssertTrue(first.waitForExistence(timeout: 4), "First note not rendered")
        // Top third, not quarter: measured geometry puts the note's top at
        // ≈106-128pt of a ≈592pt paper on iPhone 17, but the header is
        // ~fixed-height while the threshold scales with the device. Every
        // press candidate sits at ≥0.45 of the page, so top-third still
        // proves the press position was ignored.
        XCTAssertLessThan(first.frame.minY,
                          paper.frame.minY + paper.frame.height / 3,
                          "First note on an empty day should land in the top third of the page")

        // Second note: stacks below the first, never on top of it.
        XCTAssertTrue(createAnnotation(in: app, text: "stack two"),
                      "Annotation editor did not appear for the second note")
        app.buttons[ID.styleDone].tap()
        let second = app.staticTexts["stack two"]
        XCTAssertTrue(second.waitForExistence(timeout: 4), "Second note not rendered")
        XCTAssertGreaterThanOrEqual(second.frame.minY, first.frame.maxY,
                                    "Second note should stack below the first")

        // Cleanup (mandatory — the store is persistent).
        deleteAnnotationIfPresent(app, text: "stack two")
        deleteAnnotationIfPresent(app, text: "stack one")
    }

    @MainActor
    func testEventCreatedAfterNoteNudgesNoteBelowIt() {
        let app = launchOnTestDayPage()
        // Give the annotation layer time to render before purging residue
        // (purgeAllAnnotations uses .exists which is synchronous — without a
        // settle wait it exits immediately if the layer hasn't appeared yet).
        _ = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Annotation: "))
            .firstMatch.waitForExistence(timeout: 3)
        purgeAllAnnotations(app) // whole page must be empty (handles any "nudge me" residue)

        XCTAssertTrue(createAnnotation(in: app, text: "nudge me"),
                      "Annotation editor did not appear after long-press attempts")
        app.buttons[ID.styleDone].tap()
        let note = app.staticTexts["nudge me"]
        XCTAssertTrue(note.waitForExistence(timeout: 4), "Note not rendered")
        let topBefore = note.frame.minY

        // Create an event on the same day — the content column grows into
        // the band the note occupies (same recipe as EventCreateFlowUITests).
        let addLink = app.buttons["daypage.events.addRow"]
        XCTAssertTrue(addLink.waitForExistence(timeout: 5))
        addLink.tap()
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        titleField.typeText("nudge event")
        if app.keyboards.firstMatch.exists {
            app.keyboards.buttons["Return"].tap()
            _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 2)
        }
        let save = app.buttons["paperEventSheet.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 2))
        save.tap()
        _ = save.waitForNonExistence(timeout: 5)

        let eventRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "nudge event")).firstMatch
        XCTAssertTrue(eventRow.waitForExistence(timeout: 5), "Event row not visible")
        sleep(1) // let the nudge animation settle before reading frames

        // The note must have moved below the event row — no overlap.
        XCTAssertTrue(note.waitForExistence(timeout: 4), "Note vanished after event creation")
        XCTAssertGreaterThanOrEqual(note.frame.minY, eventRow.frame.maxY,
                                    "Note should be nudged below the event row")
        XCTAssertGreaterThan(note.frame.minY, topBefore,
                             "Note should have moved down from its pre-event position")

        // Cleanup (mandatory — persistent store): note first, then the event
        // via its row → sheet delete (confirmation dialog may appear).
        deleteAnnotationIfPresent(app, text: "nudge me")
        if eventRow.exists {
            eventRow.tap()
            let del = app.buttons["eventsheet.delete"]
            if del.waitForExistence(timeout: 3) {
                del.tap()
                let confirm = app.buttons["Delete"].firstMatch
                if confirm.waitForExistence(timeout: 2) { confirm.tap() }
            }
        }
    }
}
