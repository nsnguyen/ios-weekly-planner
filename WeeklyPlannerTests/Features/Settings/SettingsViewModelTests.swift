import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataSettingsStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        store = SwiftDataSettingsStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testDefaultsAfterFreshInstall() throws {
        let vm = SettingsViewModel(store: store)
        XCTAssertEqual(vm.themeKey, .cream)
        XCTAssertEqual(vm.fontKey, .caveat)
        XCTAssertEqual(vm.sizeKey, .m)
        XCTAssertEqual(vm.weekStart, .monday)
        XCTAssertEqual(vm.defaultReminderMinutes, 15)
        XCTAssertTrue(vm.appleIntelligenceEnabled)
        // AI Sticky Notes are opt-in: off until the user enables them.
        XCTAssertFalse(vm.aiStickyNotesEnabled)
    }

    func testSelectingThemePersists() throws {
        let vm = SettingsViewModel(store: store)
        vm.setTheme(.midnight)
        XCTAssertEqual(vm.themeKey, .midnight)
        let row = try store.current()
        XCTAssertEqual(row.paperTheme, .midnight)
    }

    func testSelectingFontPersists() throws {
        let vm = SettingsViewModel(store: store)
        vm.setFont(.architects)
        XCTAssertEqual(vm.fontKey, .architects)
        XCTAssertEqual(try store.current().paperFont, .architects)
    }

    func testSelectingSizePersists() throws {
        let vm = SettingsViewModel(store: store)
        vm.setSize(.l)
        XCTAssertEqual(vm.sizeKey, .l)
        XCTAssertEqual(try store.current().paperSize, .l)
    }

    func testTogglingAIPersists() throws {
        let vm = SettingsViewModel(store: store)
        XCTAssertTrue(vm.appleIntelligenceEnabled)
        vm.setAppleIntelligenceEnabled(false)
        XCTAssertFalse(vm.appleIntelligenceEnabled)
        XCTAssertFalse(try store.current().appleIntelligenceEnabled)
    }

    func testSettingDefaultReminderToNonePersists() throws {
        let vm = SettingsViewModel(store: store)
        vm.setDefaultReminderMinutes(nil)
        XCTAssertNil(vm.defaultReminderMinutes)
        XCTAssertNil(try store.current().defaultReminderMinutes)
    }

    func testDefaultWeekStartIsMonday() throws {
        let vm = SettingsViewModel(store: store)
        XCTAssertEqual(vm.weekStart, .monday)
    }

    func testSettingWeekStartPersists() throws {
        let vm = SettingsViewModel(store: store)
        vm.setWeekStart(.saturday)
        XCTAssertEqual(vm.weekStart, .saturday)
        XCTAssertEqual(try store.current().weekStart, .saturday)
        XCTAssertEqual(try store.current().weekStartRaw, 7)
    }

    func testLegacySundayBoolMigratesWhenRawUnset() throws {
        // Pre-36b installs persisted only the Bool.
        try store.update {
            $0.weekStartsOnMonday = false
            $0.weekStartRaw = 0
        }
        let vm = SettingsViewModel(store: store)
        XCTAssertEqual(vm.weekStart, .sunday)
    }
}
