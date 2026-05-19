import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class UserSettingsLastTabTests: XCTestCase {
    func testDefaultLastTabIsCalendar() throws {
        let container = try SwiftDataStack.inMemoryContainer()
        let store = SwiftDataSettingsStore(context: container.mainContext)
        let settings = try store.current()
        XCTAssertEqual(settings.lastTabRaw, "calendar")
    }

    func testLastTabRoundTripsThroughStore() throws {
        let container = try SwiftDataStack.inMemoryContainer()
        let store = SwiftDataSettingsStore(context: container.mainContext)
        try store.update { $0.lastTabRaw = "review" }
        let reloaded = try store.current()
        XCTAssertEqual(reloaded.lastTabRaw, "review")
    }
}
