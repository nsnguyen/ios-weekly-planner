import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class TabSelectionNotesTests: XCTestCase {
    private var container: ModelContainer!
    private var settings: SwiftDataSettingsStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        settings = SwiftDataSettingsStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        settings = nil
        container = nil
        try await super.tearDown()
    }

    func testTabOrderIsCalendarReviewNotesSettings() {
        // User decision 2026-06-04: Notes sits between Review and Settings.
        XCTAssertEqual(Tab.allCases, [.calendar, .review, .notes, .settings])
    }

    func testNotesSelectionPersistsAcrossRelaunch() throws {
        let selection = TabSelection(settings: settings)
        selection.current = .notes
        XCTAssertEqual(try settings.current().lastTabRaw, "notes")

        let relaunched = TabSelection(settings: settings)
        XCTAssertEqual(relaunched.current, .notes)
    }

    func testUnknownRawValueFallsBackToCalendar() throws {
        try settings.update { $0.lastTabRaw = "garbage" }
        let selection = TabSelection(settings: settings)
        XCTAssertEqual(selection.current, .calendar)
    }
}
