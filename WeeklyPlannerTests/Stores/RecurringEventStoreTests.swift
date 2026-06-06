import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class RecurringEventStoreTests: XCTestCase {
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

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h
        return WeekMath.mondayCalendar().date(from: c)!
    }

    /// "Today" = Sat Jun 6 2026; current week = Jun 1–7.
    private static func today() -> Date { date(2026, 6, 6, 12) }

    func testRecurrencePersistsThroughUpsert() async throws {
        let event = Event(title: "Gym",
                          start: Self.date(2026, 6, 1), end: Self.date(2026, 6, 1, 10),
                          category: .health,
                          recurrence: Recurrence(frequency: .weekly))
        try await store.upsert(event)

        let fetched = try await store.event(id: event.id)
        XCTAssertEqual(fetched?.recurrence, Recurrence(frequency: .weekly))
        XCTAssertEqual(fetched?.isRecurring, true)
    }

    func testWeeklySeriesFromPastWeekAppearsInCurrentWeekFetch() async throws {
        // Master anchored 3 weeks before "today" — base start-in-window
        // predicate alone would miss it.
        let master = Event(title: "Standup",
                           start: Self.date(2026, 5, 11), end: Self.date(2026, 5, 11, 10),
                           category: .work,
                           recurrence: Recurrence(frequency: .weekly))
        try await store.upsert(master)

        let thisWeek = try await store.events(forWeekOffset: 0, today: Self.today())
        XCTAssertEqual(thisWeek.count, 1)
        XCTAssertEqual(thisWeek.first?.title, "Standup")
        XCTAssertEqual(thisWeek.first?.id, master.id, "Occurrence copies carry the master id")
        XCTAssertEqual(thisWeek.first?.start, Self.date(2026, 6, 1), "Occurrence lands on this week's Monday")
    }

    func testDailySeriesYieldsOneOccurrencePerDay() async throws {
        let master = Event(title: "Walk",
                           start: Self.date(2026, 6, 1), end: Self.date(2026, 6, 1, 10),
                           category: .health,
                           recurrence: Recurrence(frequency: .daily))
        try await store.upsert(master)

        let thisWeek = try await store.events(forWeekOffset: 0, today: Self.today())
        XCTAssertEqual(thisWeek.count, 7)
        XCTAssertEqual(Set(thisWeek.map(\.id)).count, 1)
    }

    func testSingleEventsAreUnaffected() async throws {
        let single = Event(title: "Dentist",
                           start: Self.date(2026, 6, 3), end: Self.date(2026, 6, 3, 10),
                           category: .personal)
        try await store.upsert(single)

        let thisWeek = try await store.events(forWeekOffset: 0, today: Self.today())
        XCTAssertEqual(thisWeek.map(\.title), ["Dentist"])
        let nextWeek = try await store.events(forWeekOffset: 1, today: Self.today())
        XCTAssertTrue(nextWeek.isEmpty)
    }

    func testDeleteOccurrenceExcludesOnlyThatDay() async throws {
        let master = Event(title: "Walk",
                           start: Self.date(2026, 6, 1), end: Self.date(2026, 6, 1, 10),
                           category: .health,
                           recurrence: Recurrence(frequency: .daily))
        try await store.upsert(master)

        try await store.deleteOccurrence(eventID: master.id, occurrenceStart: Self.date(2026, 6, 3))

        let thisWeek = try await store.events(forWeekOffset: 0, today: Self.today())
        XCTAssertEqual(thisWeek.count, 6)
        XCTAssertFalse(thisWeek.contains { $0.start == Self.date(2026, 6, 3) })
    }

    func testDeleteSeriesRemovesAllOccurrences() async throws {
        let master = Event(title: "Walk",
                           start: Self.date(2026, 6, 1), end: Self.date(2026, 6, 1, 10),
                           category: .health,
                           recurrence: Recurrence(frequency: .daily))
        try await store.upsert(master)
        try await store.delete(id: master.id)

        let thisWeek = try await store.events(forWeekOffset: 0, today: Self.today())
        XCTAssertTrue(thisWeek.isEmpty)
    }
}
