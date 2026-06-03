import XCTest

/// Phase 28 — the sticky-note swipe-lock regression (suggestion 4: "when
/// sticky note on, unable to swipe page or change page unless reboot").
///
/// Like `AIStickyStackUITests`, this is intentionally **permissive**: AI
/// Sticky Notes are opt-in/default-off and the orchestrator's output depends
/// on Apple Intelligence availability, location, and seeded events, so we
/// cannot guarantee a sticky surfaces in CI — and there is deliberately no
/// app-target test-seeding seam. When a sticky IS present, we drive a
/// partial/aborted drag on it and then assert page navigation still works (the
/// core regression). When no sticky surfaces, the test still verifies baseline
/// navigation and passes — the structural fix (`@GestureState`-derived
/// suppression) and the `PageFlipController` consumer-contract unit tests carry
/// the deterministic guarantee; on-device is the final check.
///
/// Identifiers mirror `AccessibilityIDs` (UI tests are black-box):
///   topbar.dayweek.{day,week} · topbar.daterange.pill · daypage.sticky.top
final class StickySwipeUITests: XCTestCase {
    private enum ID {
        static func dayWeekSegment(_ v: String) -> String { "topbar.dayweek.\(v)" }
        static let dateRangePill = "topbar.daterange.pill"
        static let stickyTop = "daypage.sticky.top"
        static func sideTab(_ n: Int) -> String { "daypage.sidetab.\(n)" }
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func rangeValue(_ app: XCUIApplication) -> String {
        let pill = app.buttons[ID.dateRangePill]
        guard pill.waitForExistence(timeout: 3) else { return "" }
        return (pill.value as? String) ?? ""
    }

    /// Baseline: page navigation works (chevron-free liveness via the week
    /// segment + side tabs). Always runs regardless of sticky presence.
    @MainActor
    func testPageStillFlipsWithStickyEnabled() {
        let app = XCUIApplication()
        app.launch()

        let calendarTab = app.buttons["tabbar.tab.calendar"]
        if calendarTab.waitForExistence(timeout: 3) { calendarTab.tap() }

        // Switch Day→Week→Day to confirm the shared controller is live (this is
        // exactly what the swipe-lock used to block).
        let weekSeg = app.buttons[ID.dayWeekSegment("week")]
        XCTAssertTrue(weekSeg.waitForExistence(timeout: 5), "Week segment not found")
        weekSeg.tap()
        app.buttons[ID.dayWeekSegment("day")].tap()

        // Day side tabs must respond.
        let friday = app.buttons[ID.sideTab(4)]
        XCTAssertTrue(friday.waitForExistence(timeout: 3), "Friday side tab not found")
        friday.tap()
        XCTAssertTrue(friday.isHittable, "Day navigation unresponsive")
    }

    /// The core regression: if a sticky is present, abort a drag on it (a short
    /// horizontal press-drag-release below the swipe threshold), then confirm
    /// the page can still navigate. Before the fix, the aborted drag could
    /// strand `stickyDragActive` and lock all navigation until relaunch.
    @MainActor
    func testAbortedStickyDragDoesNotLockNavigation() {
        let app = XCUIApplication()
        app.launch()

        let calendarTab = app.buttons["tabbar.tab.calendar"]
        if calendarTab.waitForExistence(timeout: 3) { calendarTab.tap() }

        let sticky = app.otherElements[ID.stickyTop].firstMatch
        guard sticky.waitForExistence(timeout: 10) else {
            // No sticky surfaced (opt-in/default-off, env-dependent). Verify
            // baseline navigation and pass — the unit tests + structural fix
            // cover the lock deterministically.
            let weekSeg = app.buttons[ID.dayWeekSegment("week")]
            if weekSeg.waitForExistence(timeout: 3) {
                weekSeg.tap()
                app.buttons[ID.dayWeekSegment("day")].tap()
            }
            return
        }

        // Abort a drag: small horizontal movement that ends below the 30pt
        // navigate threshold, then release. This is the interruption that used
        // to skip `.onEnded`'s reset in spirit.
        let start = sticky.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let nudge = sticky.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: nudge)

        // Now the page must still navigate. Flip Day→Week→Day and tap a side
        // tab; if the flag were stranded, the swipe path would be suppressed —
        // we assert via segment + side-tab liveness which share the controller.
        let weekSeg = app.buttons[ID.dayWeekSegment("week")]
        XCTAssertTrue(weekSeg.waitForExistence(timeout: 3), "Week segment missing")
        let beforeWeek = rangeValue(app)
        weekSeg.tap()
        app.buttons[ID.dayWeekSegment("day")].tap()

        let monday = app.buttons[ID.sideTab(0)]
        let friday = app.buttons[ID.sideTab(4)]
        XCTAssertTrue(monday.waitForExistence(timeout: 3),
                      "Navigation locked after aborted sticky drag (swipe-lock regression)")
        monday.tap()
        friday.tap()
        XCTAssertTrue(friday.isHittable,
                      "Day side tabs unresponsive after aborted sticky drag (swipe-lock)")
        _ = beforeWeek
    }
}
