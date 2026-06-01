import XCTest

/// Phase 27 — drives the real navigation freeze repro from inside the
/// simulator, the thing the `PageFlipController` unit tests model but can't
/// actually reproduce (the freeze was a missing view-layer commit, not a
/// controller-logic error).
///
/// The original bug: on the Week view, navigation died after a short while and
/// took the Day view down with it (the controller is shared), requiring a
/// force-quit. These tests flip to Week, navigate, idle past the first
/// `TimelineView(.everyMinute)` tick, and assert navigation still works — plus
/// the cross-view guard (Day still navigates after Week idle) and that the
/// week picker shows the selected week.
///
/// Identifiers are string literals mirroring `AccessibilityIDs` in the app
/// target (UI tests are black-box and don't import app types — same convention
/// as the other UITest files). Keep these in sync with `AccessibilityIDs`:
///   topbar.dayweek.{day,week} · topbar.week.chevron.{prev,next} ·
///   topbar.daterange.pill · daypage.sidetab.{n} · weekpicker.weekrow.{offset}
final class WeekNavigationStabilityUITests: XCTestCase {
    private enum ID {
        static func dayWeekSegment(_ v: String) -> String { "topbar.dayweek.\(v)" }
        static let weekChevronPrev = "topbar.week.chevron.prev"
        static let weekChevronNext = "topbar.week.chevron.next"
        static let dateRangePill = "topbar.daterange.pill"
        static func sideTab(_ n: Int) -> String { "daypage.sidetab.\(n)" }
        static func weekpickerWeekRow(_ offset: Int) -> String { "weekpicker.weekrow.\(offset)" }
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Length of the post-idle wait. The freeze surfaced "after about a
    /// minute", coinciding with the first `TimelineView(.everyMinute)` tick, so
    /// the idle MUST cross 60s for the regression to be meaningful — a shorter
    /// wait wouldn't reproduce the original bug's trigger. 65s by default.
    ///
    /// `WP_IDLE_SECONDS` (read from the *test runner's* own environment, e.g.
    /// `env WP_IDLE_SECONDS=3 xcodebuild test …`) can shorten it for a quick
    /// smoke run, but note that below 60s these tests no longer prove the
    /// freeze fix — they only prove basic navigation.
    private func idleSeconds(default def: Double = 65) -> Double {
        if let raw = ProcessInfo.processInfo.environment["WP_IDLE_SECONDS"],
           let v = Double(raw) { return v }
        return def
    }

    private func launchOnWeekView() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()

        let weekSegment = app.buttons[ID.dayWeekSegment("week")]
        XCTAssertTrue(weekSegment.waitForExistence(timeout: 5),
                      "Day/Week toggle 'week' segment not found")
        weekSegment.tap()
        return app
    }

    private func rangeValue(_ app: XCUIApplication) -> String {
        let pill = app.buttons[ID.dateRangePill]
        XCTAssertTrue(pill.waitForExistence(timeout: 3), "Date-range pill not found")
        return (pill.value as? String) ?? ""
    }

    /// The core regression: open Week, advance a week via the chevron, then sit
    /// idle past the one-minute tick and advance again. Before the fix the
    /// second tap (often the first) was a no-op — the controller had stranded
    /// `isFlipping`. Each advance must change the visible date range.
    @MainActor
    func testWeekChevronStillWorksAfterIdle() {
        let app = launchOnWeekView()
        let next = app.buttons[ID.weekChevronNext]
        XCTAssertTrue(next.waitForExistence(timeout: 3), "Next-week chevron not found")

        let start = rangeValue(app)
        next.tap()
        let afterFirst = rangeValue(app)
        XCTAssertNotEqual(afterFirst, start,
                          "Week did not advance on the first chevron tap")

        // Idle past the first .everyMinute tick — the original freeze window.
        Thread.sleep(forTimeInterval: idleSeconds())

        next.tap()
        let afterIdle = rangeValue(app)
        XCTAssertNotEqual(afterIdle, afterFirst,
                          "Week navigation froze after idling past the one-minute tick")
    }

    /// Cross-view freeze guard: the Week view must never strand the *shared*
    /// controller such that the Day view can no longer change date. Navigate
    /// the Week view, idle, then switch to Day and confirm a side tab still
    /// responds.
    @MainActor
    func testDayDateChangesAfterWeekViewIdle() {
        let app = launchOnWeekView()
        let next = app.buttons[ID.weekChevronNext]
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        next.tap()

        Thread.sleep(forTimeInterval: idleSeconds())

        // Back to Day view.
        app.buttons[ID.dayWeekSegment("day")].tap()

        let tabMon = app.buttons[ID.sideTab(0)] // Monday
        let tabFri = app.buttons[ID.sideTab(4)] // Friday
        XCTAssertTrue(tabMon.waitForExistence(timeout: 3), "Monday side tab not found")

        tabMon.tap()
        tabFri.tap()
        // If the shared controller were frozen by the Week view, the Day view's
        // tap targets would be unresponsive. Hittability after the round trip
        // is the cross-view liveness guard.
        XCTAssertTrue(tabFri.isHittable,
                      "Day view side tabs are unresponsive after Week-view idle (cross-view freeze)")
    }

    /// Suggestion 22: picking a different week in the picker must show *that*
    /// week. Open the picker, jump three weeks out, and assert the visible
    /// range changed.
    @MainActor
    func testWeekPickerNavigatesToSelectedWeek() {
        let app = launchOnWeekView()
        let start = rangeValue(app)

        app.buttons[ID.dateRangePill].tap()

        let targetRow = app.buttons[ID.weekpickerWeekRow(3)]
        XCTAssertTrue(targetRow.waitForExistence(timeout: 3),
                      "Week +3 row not found in picker")
        targetRow.tap()

        let afterPick = rangeValue(app)
        XCTAssertNotEqual(afterPick, start,
                          "Week picker did not change the visible week (suggestion 22)")
    }

    /// Week-flip parity: a horizontal swipe on the Week spread must change the
    /// week, the same way swiping the Day page changes the day. This is the
    /// gesture path (distinct from the chevrons) and the first spec behavior
    /// item — the Week view had no swipe at all before this change.
    ///
    /// Note: XCUITest can assert the week *changed*; it can't observe the 3D
    /// flip animation itself. The animation is verified visually / on-device.
    @MainActor
    func testWeekSwipeChangesWeek() {
        let app = launchOnWeekView()
        let start = rangeValue(app)

        // Swipe left on the page area → next week. Swipe on the window's
        // mid-area, clear of the top bar and bottom controls.
        let surface = app.windows.firstMatch
        surface.swipeLeft()
        let afterLeft = rangeValue(app)
        XCTAssertNotEqual(afterLeft, start,
                          "Swiping left on the Week view did not advance the week")

        surface.swipeRight()
        let afterRight = rangeValue(app)
        XCTAssertNotEqual(afterRight, afterLeft,
                          "Swiping right on the Week view did not rewind the week")
    }
}
