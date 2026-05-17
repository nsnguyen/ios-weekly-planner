import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class SettingsStoreTests: XCTestCase {
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

    func testDefaultsMatchSpec() throws {
        let settings = try store.current()
        XCTAssertEqual(settings.paperTheme, .cream)
        XCTAssertEqual(settings.paperFont, .caveat)
        XCTAssertEqual(settings.paperSize, .m)
        XCTAssertTrue(settings.weekStartsOnMonday)
        XCTAssertEqual(settings.defaultReminderMinutes, 15)
        XCTAssertTrue(settings.appleIntelligenceEnabled)
        XCTAssertFalse(settings.gmailConnected)
        XCTAssertTrue(settings.appleMailConnected)
        XCTAssertEqual(settings.style, .paper)
        XCTAssertEqual(settings.paperView, .day)
        XCTAssertEqual(settings.modernView, .day)
        XCTAssertEqual(settings.accentHex, "#0A84FF")
    }

    func testCurrentReturnsSameRowOnSubsequentCalls() throws {
        let first = try store.current()
        let second = try store.current()
        XCTAssertEqual(first.id, second.id)
        let count = try container.mainContext.fetch(FetchDescriptor<UserSettings>()).count
        XCTAssertEqual(count, 1)
    }

    func testUpdatePersistsAcrossNewStore() throws {
        try store.update { settings in
            settings.paperTheme = .midnight
            settings.paperFont = .kalam
        }

        let reopened = SwiftDataSettingsStore(context: container.mainContext)
        let settings = try reopened.current()
        XCTAssertEqual(settings.paperTheme, .midnight)
        XCTAssertEqual(settings.paperFont, .kalam)
    }
}
