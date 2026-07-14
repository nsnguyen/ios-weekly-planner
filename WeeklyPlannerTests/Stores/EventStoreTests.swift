import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventStoreTests: XCTestCase {
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

    /// Anchor every test on Sat May 16, 2026 so week math is deterministic.
    private static func may16_2026(hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = hour
        return WeekMath.mondayCalendar().date(from: components) ?? Date()
    }

    func testUpsertNewEventInsertsIt() async throws {
        let event = Event(title: "Standup",
                          start: Self.may16_2026(hour: 9),
                          end: Self.may16_2026(hour: 10),
                          category: .work)
        try await store.upsert(event)
        let fetched = try await store.event(id: event.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Standup")
    }

    func testUpsertExistingEventUpdatesInPlace() async throws {
        let id = UUID()
        let original = Event(id: id,
                             title: "Old",
                             start: Self.may16_2026(hour: 9),
                             end: Self.may16_2026(hour: 10),
                             category: .work)
        try await store.upsert(original)

        let updated = Event(id: id,
                            title: "New",
                            start: Self.may16_2026(hour: 9),
                            end: Self.may16_2026(hour: 11),
                            category: .work)
        try await store.upsert(updated)

        let count = try container.mainContext.fetch(FetchDescriptor<Event>()).count
        XCTAssertEqual(count, 1, "Upsert should update, not insert a second row")
        let refreshed = try await store.event(id: id)
        XCTAssertEqual(refreshed?.title, "New")
    }

    func testUpsertExistingEventPreservesGoogleEtagAndUpdatedAt() async throws {
        let id = UUID()
        let original = Event(id: id,
                             title: "Old",
                             start: Self.may16_2026(hour: 9),
                             end: Self.may16_2026(hour: 10),
                             category: .work,
                             googleEventID: "gid",
                             googleEtag: "\"old\"")
        try await store.upsert(original)

        let updatedAt = Date(timeIntervalSince1970: 1234)
        let updated = Event(id: id,
                            title: "New",
                            start: Self.may16_2026(hour: 9),
                            end: Self.may16_2026(hour: 11),
                            category: .work,
                            googleEventID: "gid",
                            googleEtag: "\"new\"",
                            updatedAt: updatedAt)
        try await store.upsert(updated)

        let refreshed = try await store.event(id: id)
        XCTAssertEqual(refreshed?.googleEtag, "\"new\"")
        XCTAssertEqual(refreshed?.updatedAt, updatedAt)
    }

    func testUpsertExistingGoogleEventUpdatesInPlaceByGoogleEventID() async throws {
        let originalID = UUID()
        let importedID = UUID()
        let original = Event(id: originalID,
                             title: "Local write-back",
                             start: Self.may16_2026(hour: 9),
                             end: Self.may16_2026(hour: 10),
                             category: .work,
                             source: .googleCalendar,
                             googleEventID: "gid1",
                             googleEtag: "\"old\"")
        try await store.upsert(original)

        let updatedAt = Date(timeIntervalSince1970: 2_345)
        let imported = Event(id: importedID,
                             title: "Imported update",
                             start: Self.may16_2026(hour: 11),
                             end: Self.may16_2026(hour: 12),
                             category: .personal,
                             source: .googleCalendar,
                             googleEventID: "gid1",
                             googleEtag: "\"new\"",
                             updatedAt: updatedAt)
        try await store.upsert(imported)

        let all = try container.mainContext.fetch(FetchDescriptor<Event>())
        let matching = all.filter { $0.googleEventID == "gid1" }
        XCTAssertEqual(matching.count, 1, "Upsert should not duplicate rows that share googleEventID")
        let fetched = try XCTUnwrap(matching.first)
        XCTAssertEqual(fetched.id, originalID)
        XCTAssertEqual(fetched.title, "Imported update")
        XCTAssertEqual(fetched.googleEtag, "\"new\"")
        XCTAssertEqual(fetched.updatedAt, updatedAt)
        let insertedByImportedID = try await store.event(id: importedID)
        XCTAssertNil(insertedByImportedID)
    }

    func testFetchByWeekOffsetReturnsEventsInRange() async throws {
        let thisWeek = Event(title: "This week",
                             start: Self.may16_2026(hour: 9),
                             end: Self.may16_2026(hour: 10),
                             category: .work)
        // Build a date in the next week (May 18, 2026 is Monday of week +1).
        var next = DateComponents()
        next.year = 2026
        next.month = 5
        next.day = 18
        next.hour = 9
        let nextWeekStart = try XCTUnwrap(WeekMath.mondayCalendar().date(from: next))
        let nextWeek = Event(title: "Next week",
                             start: nextWeekStart,
                             end: nextWeekStart.addingTimeInterval(3600),
                             category: .work)

        try await store.upsert(thisWeek)
        try await store.upsert(nextWeek)

        let current = try await store.events(forWeekOffset: 0, today: Self.may16_2026())
        let upcoming = try await store.events(forWeekOffset: 1, today: Self.may16_2026())
        XCTAssertEqual(current.map(\.title), ["This week"])
        XCTAssertEqual(upcoming.map(\.title), ["Next week"])
    }

    func testDeleteRemovesEvent() async throws {
        let event = Event(title: "Doomed",
                          start: Self.may16_2026(),
                          end: Self.may16_2026(hour: 13),
                          category: .personal)
        try await store.upsert(event)
        try await store.delete(id: event.id)
        let after = try await store.event(id: event.id)
        XCTAssertNil(after)
    }
}
