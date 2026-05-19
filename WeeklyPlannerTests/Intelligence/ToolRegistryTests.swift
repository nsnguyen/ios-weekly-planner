import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class ToolRegistryTests: XCTestCase {
    private var container: ModelContainer!
    private var events: SwiftDataEventStore!
    private var tasks: SwiftDataTaskStore!
    private var inbox: SwiftDataInboxStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        events = SwiftDataEventStore(context: container.mainContext)
        tasks = SwiftDataTaskStore(context: container.mainContext)
        inbox = SwiftDataInboxStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        events = nil; tasks = nil; inbox = nil; container = nil
        try await super.tearDown()
    }

    func testRegistryExposesFiveToolsInStableOrder() {
        let registry = ToolRegistry(events: events, tasks: tasks, inbox: inbox)
        let names = registry.allTools.map(\.name)
        XCTAssertEqual(names, ["findEvents", "findFreeSlots", "scanInbox", "summarizeWeek", "lastInteraction"])
    }

    func testToolEventResultRoundTripsThroughCodable() throws {
        let id = UUID()
        let result = ToolEventResult(
            id: id,
            title: "Dentist follow-up",
            start: Date(timeIntervalSince1970: 1_780_000_000),
            end: Date(timeIntervalSince1970: 1_780_003_600),
            location: "4th Street Dental",
            categoryRaw: "health",
            sourceRaw: "manual"
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(ToolEventResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }
}
