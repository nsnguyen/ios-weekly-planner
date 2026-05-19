import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class FindEventsToolTests: XCTestCase {
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

    func testRunReturnsCompactDTOs() async throws {
        let anchor = Self.may16_2026(hour: 9)
        try await store.upsert(Event(
            title: "Dentist follow-up",
            start: anchor,
            end: anchor.addingTimeInterval(1800),
            location: "4th Street Dental",
            category: .health
        ))
        let tool = FindEventsTool(store: store)
        let results = try await tool.run(query: EventQuery(
            dateRange: anchor ... anchor.addingTimeInterval(7200),
            categories: [.health],
            keywords: [],
            personName: nil
        ))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Dentist follow-up")
        XCTAssertEqual(results.first?.categoryRaw, "health")
        XCTAssertEqual(results.first?.location, "4th Street Dental")
    }

    func testRunReturnsEmptyOnThrowingStore() async throws {
        final class ThrowingStore: EventStoring {
            func events(forWeekOffset: Int, today: Date) async throws -> [Event] { [] }
            func event(id: UUID) async throws -> Event? { nil }
            func upsert(_ event: Event) async throws {}
            func delete(id: UUID) async throws {}
            func events(matching query: EventQuery) async throws -> [Event] {
                struct Boom: Error {}
                throw Boom()
            }
        }
        let tool = FindEventsTool(store: ThrowingStore())
        let results = try await tool.run(query: EventQuery(
            dateRange: Date() ... Date().addingTimeInterval(3600),
            categories: nil,
            keywords: [],
            personName: nil
        ))
        XCTAssertTrue(results.isEmpty)
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
