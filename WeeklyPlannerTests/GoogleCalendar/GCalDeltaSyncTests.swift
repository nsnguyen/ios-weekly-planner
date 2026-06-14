import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class GCalDeltaSyncTests: XCTestCase {
    private var container: ModelContainer!
    private var settingsStore: SwiftDataSettingsStore!
    private var deltaSync: GCalDeltaSync!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        deltaSync = GCalDeltaSync(settingsStore: settingsStore)
    }

    override func tearDown() async throws {
        deltaSync = nil
        settingsStore = nil
        container = nil
        try await super.tearDown()
    }

    func testCurrentTokenIsNilInitially() {
        XCTAssertNil(deltaSync.currentToken())
    }

    func testSaveAndReadToken() {
        deltaSync.save("TOK")
        XCTAssertEqual(deltaSync.currentToken(), "TOK")
    }

    func testSaveNilClearsToken() {
        deltaSync.save("TOK")
        deltaSync.save(nil)
        XCTAssertNil(deltaSync.currentToken())
    }
}
