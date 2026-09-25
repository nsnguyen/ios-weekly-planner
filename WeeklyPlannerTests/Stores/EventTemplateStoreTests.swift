import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventTemplateStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataEventTemplateStore!
    private var settings: SwiftDataSettingsStore!

    override func setUp() async throws {
        container = try SwiftDataStack.inMemoryContainer()
        let context = container.mainContext
        store = SwiftDataEventTemplateStore(context: context)
        settings = SwiftDataSettingsStore(context: context)
    }

    override func tearDown() async throws {
        store = nil
        settings = nil
        container = nil
    }

    func testSeedIfNeededInsertsCuratedOnceOnly() throws {
        try store.seedIfNeeded(from: EventTemplate.curated, settings: settings)
        XCTAssertEqual(try store.templates().count, EventTemplate.curated.count)
        XCTAssertTrue(try settings.current().eventTemplatesSeeded)

        for record in try store.templates() {
            try store.delete(id: record.id)
        }
        try store.seedIfNeeded(from: EventTemplate.curated, settings: settings)
        XCTAssertEqual(try store.templates().count, 0, "Deleting all chips must be durable")
    }

    func testTemplatesSortedBySortOrder() throws {
        try store.seedIfNeeded(from: EventTemplate.curated, settings: settings)
        let titles = try store.templates().map(\.title)
        XCTAssertEqual(titles, EventTemplate.curated.map(\.title), "Seed preserves curated order")
    }

    func testSeedKeepsCuratedChipIdentifiers() throws {
        try store.seedIfNeeded(from: EventTemplate.curated, settings: settings)
        let keys = try store.templates().map(\.asTemplate.id)
        XCTAssertEqual(keys, EventTemplate.curated.map(\.id))
    }

    func testAddAppendsAtEnd() throws {
        try store.seedIfNeeded(from: EventTemplate.curated, settings: settings)
        try store.add(title: "Swim", category: .personal, durationMinutes: 45)
        let all = try store.templates()
        XCTAssertEqual(all.last?.title, "Swim")
        XCTAssertEqual(all.last?.durationMinutes, 45)
    }

    func testDeleteRemovesRecord() throws {
        try store.seedIfNeeded(from: EventTemplate.curated, settings: settings)
        let first = try XCTUnwrap(try store.templates().first)
        try store.delete(id: first.id)
        XCTAssertFalse(try store.templates().contains { $0.id == first.id })
    }

    func testRecordConvertsToEventTemplate() throws {
        try store.add(title: "Swim", category: .personal, durationMinutes: 45)
        let template = try XCTUnwrap(try store.templates().first?.asTemplate)
        XCTAssertEqual(template.title, "Swim")
        XCTAssertEqual(template.durationMinutes, 45)
        XCTAssertEqual(template.category, .personal)
    }
}
