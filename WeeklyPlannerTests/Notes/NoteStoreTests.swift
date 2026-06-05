import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class NoteStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataNoteStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        store = SwiftDataNoteStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testUpsertNewNoteInsertsIt() async throws {
        let note = Note(title: "Marathon", body: "Sub-4 this year", kind: .goal)
        try await store.upsert(note)

        let fetched = try await store.note(id: note.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Marathon")
        XCTAssertEqual(fetched?.kind, .goal)
        XCTAssertNil(fetched?.dayKey, "dayKey is reserved and must default to nil")
    }

    func testUpsertExistingNoteUpdatesInPlace() async throws {
        let id = UUID()
        try await store.upsert(Note(id: id, title: "Old", body: "old body"))
        try await store.upsert(Note(id: id, title: "New", body: "new body", kind: .goal))

        let count = try container.mainContext.fetch(FetchDescriptor<Note>()).count
        XCTAssertEqual(count, 1, "Upsert should update, not insert a second row")
        let fetched = try await store.note(id: id)
        XCTAssertEqual(fetched?.title, "New")
        XCTAssertEqual(fetched?.kind, .goal)
    }

    func testNotesSortedMostRecentlyUpdatedFirst() async throws {
        try await store.upsert(Note(title: "Old", body: "", updatedAt: Date(timeIntervalSince1970: 1_000)))
        try await store.upsert(Note(title: "New", body: "", updatedAt: Date(timeIntervalSince1970: 2_000)))

        let notes = try await store.notes()
        XCTAssertEqual(notes.map(\.title), ["New", "Old"])
    }

    func testDeleteRemovesNote() async throws {
        let note = Note(title: "Bye", body: "")
        try await store.upsert(note)
        try await store.delete(id: note.id)

        let fetched = try await store.note(id: note.id)
        XCTAssertNil(fetched)
        let remaining = try await store.notes()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testMutationsPostChangeNotification() async throws {
        let exp = expectation(forNotification: .noteStoreDidChange, object: nil)
        try await store.upsert(Note(title: "Ping", body: ""))
        await fulfillment(of: [exp], timeout: 1)
    }
}
