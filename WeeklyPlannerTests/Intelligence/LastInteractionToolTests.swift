import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class LastInteractionToolTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataEventStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        store = SwiftDataEventStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil; container = nil
        try await super.tearDown()
    }

    func testReturnsMostRecentMatchBeforeToday() async throws {
        let today = Self.may16_2026(hour: 12)
        let saraOld = Self.may16_2026(hour: 9).addingTimeInterval(-14 * 86_400)
        let saraNew = Self.may16_2026(hour: 9).addingTimeInterval(-2 * 86_400)
        try await store.upsert(Event(title: "Coffee with Sara", start: saraOld,
                                     end: saraOld.addingTimeInterval(1800), category: .personal))
        try await store.upsert(Event(title: "Sara's birthday breakfast", start: saraNew,
                                     end: saraNew.addingTimeInterval(1800), category: .personal))

        let tool = LastInteractionTool(store: store)
        let result = try await tool.run(personName: "Sara", today: today)
        XCTAssertNotNil(result.eventID)
        XCTAssertEqual(result.context, "Sara's birthday breakfast")
        XCTAssertEqual(result.date, saraNew)
    }

    func testReturnsEmptyWhenNoMatch() async throws {
        let today = Self.may16_2026(hour: 12)
        let tool = LastInteractionTool(store: store)
        let result = try await tool.run(personName: "Nobody", today: today)
        XCTAssertNil(result.eventID)
        XCTAssertNil(result.date)
        XCTAssertEqual(result.context, "")
    }

    private static func may16_2026(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }
}
