import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventQueryTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataEventStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        store = SwiftDataEventStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testMatchingFiltersByCategory() async throws {
        let anchor = Self.may16_2026(hour: 9)
        try await store.upsert(Event(title: "Run", start: anchor, end: anchor.addingTimeInterval(1800), category: .health))
        try await store.upsert(Event(title: "Standup", start: anchor.addingTimeInterval(3600),
                                     end: anchor.addingTimeInterval(5400), category: .work))

        let query = EventQuery(
            dateRange: anchor ... anchor.addingTimeInterval(7200),
            categories: [.health],
            keywords: [],
            personName: nil
        )
        let results = try await store.events(matching: query)
        XCTAssertEqual(results.map(\.title), ["Run"])
    }

    func testMatchingFiltersByKeywordCaseInsensitive() async throws {
        let anchor = Self.may16_2026(hour: 9)
        try await store.upsert(Event(title: "Dentist follow-up", start: anchor,
                                     end: anchor.addingTimeInterval(1800), category: .health))
        try await store.upsert(Event(title: "Pitch deck review", start: anchor.addingTimeInterval(3600),
                                     end: anchor.addingTimeInterval(5400), category: .work))

        let query = EventQuery(
            dateRange: anchor ... anchor.addingTimeInterval(7200),
            categories: nil,
            keywords: ["DENTIST"],
            personName: nil
        )
        let results = try await store.events(matching: query)
        XCTAssertEqual(results.map(\.title), ["Dentist follow-up"])
    }

    func testMatchingFiltersByPersonName() async throws {
        let anchor = Self.may16_2026(hour: 9)
        try await store.upsert(Event(title: "Coffee with Sara", start: anchor,
                                     end: anchor.addingTimeInterval(1800), category: .personal))
        try await store.upsert(Event(title: "Team sync", start: anchor.addingTimeInterval(3600),
                                     end: anchor.addingTimeInterval(5400), category: .work))

        let query = EventQuery(
            dateRange: anchor ... anchor.addingTimeInterval(7200),
            categories: nil,
            keywords: [],
            personName: "sara"
        )
        let results = try await store.events(matching: query)
        XCTAssertEqual(results.map(\.title), ["Coffee with Sara"])
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
