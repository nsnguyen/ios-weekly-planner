import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class TabSelectionTests: XCTestCase {
    private var container: ModelContainer!
    private var settingsStore: SwiftDataSettingsStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        settingsStore = SwiftDataSettingsStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        settingsStore = nil; container = nil
        try await super.tearDown()
    }

    func testDefaultTabIsCalendar() throws {
        let selection = TabSelection(settings: settingsStore)
        XCTAssertEqual(selection.current, .calendar)
    }

    func testSwitchingTabPersistsThroughSettingsStore() throws {
        let selection = TabSelection(settings: settingsStore)
        selection.current = .review
        let reloaded = try settingsStore.current()
        XCTAssertEqual(reloaded.lastTabRaw, "review")
    }

    func testFreshInstanceRestoresPersistedTab() throws {
        try settingsStore.update { $0.lastTabRaw = "settings" }
        let selection = TabSelection(settings: settingsStore)
        XCTAssertEqual(selection.current, .settings)
    }

    func testUnknownPersistedValueFallsBackToCalendar() throws {
        try settingsStore.update { $0.lastTabRaw = "garbage" }
        let selection = TabSelection(settings: settingsStore)
        XCTAssertEqual(selection.current, .calendar)
    }
}
