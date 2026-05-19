import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class FindFreeSlotsToolTests: XCTestCase {
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

    func testFindsThirtyMinuteSlotBeforeFirstEvent() async throws {
        let dayStart = Self.may16_2026(hour: 8)
        let firstEventStart = Self.may16_2026(hour: 10)
        let firstEventEnd = Self.may16_2026(hour: 11)
        try await store.upsert(Event(title: "Standup", start: firstEventStart, end: firstEventEnd, category: .work))

        let tool = FindFreeSlotsTool(store: store)
        let slots = try await tool.run(
            dateRange: dayStart ... Self.may16_2026(hour: 18),
            minMinutes: 30,
            dayPart: .morning
        )
        XCTAssertFalse(slots.isEmpty)
        XCTAssertTrue(slots.allSatisfy { $0.end.timeIntervalSince($0.start) >= 30 * 60 })
        XCTAssertTrue(slots.first!.start >= dayStart)
        XCTAssertTrue(slots.first!.end <= firstEventStart)
    }

    func testEmptyDayProducesOneSlotSpanningRange() async throws {
        let dayStart = Self.may16_2026(hour: 8)
        let dayEnd = Self.may16_2026(hour: 18)
        let tool = FindFreeSlotsTool(store: store)
        let slots = try await tool.run(
            dateRange: dayStart ... dayEnd,
            minMinutes: 30,
            dayPart: .any
        )
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots[0].start, dayStart)
        XCTAssertEqual(slots[0].end, dayEnd)
    }

    func testCapsAtFiveResults() async throws {
        let dayStart = Self.may16_2026(hour: 8)
        for offset in 0 ..< 12 {
            let s = dayStart.addingTimeInterval(Double(offset) * 45 * 60)
            try await store.upsert(Event(title: "E\(offset)", start: s,
                                         end: s.addingTimeInterval(15 * 60), category: .work))
        }
        let tool = FindFreeSlotsTool(store: store)
        let slots = try await tool.run(
            dateRange: dayStart ... dayStart.addingTimeInterval(12 * 60 * 60),
            minMinutes: 15,
            dayPart: .any
        )
        XCTAssertLessThanOrEqual(slots.count, 5)
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
