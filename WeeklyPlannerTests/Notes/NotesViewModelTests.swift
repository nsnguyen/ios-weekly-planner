import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class NotesViewModelTests: XCTestCase {
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

    func testLoadStartsEmpty() async throws {
        let vm = NotesViewModel(store: store)
        await vm.load()
        XCTAssertTrue(vm.notes.isEmpty)
    }

    func testCreatePersistsTrimmedNoteAndReloads() async throws {
        let vm = NotesViewModel(store: store)
        await vm.load()

        let created = await vm.create(title: "  Groceries  ", body: "milk, eggs\n", kind: .misc)

        XCTAssertNotNil(created)
        XCTAssertEqual(vm.notes.count, 1)
        XCTAssertEqual(vm.notes.first?.title, "Groceries")
        XCTAssertEqual(vm.notes.first?.body, "milk, eggs")
        XCTAssertEqual(vm.notes.first?.kind, .misc)
    }

    func testCreateDiscardsEmptyDraft() async throws {
        let vm = NotesViewModel(store: store)
        await vm.load()

        let created = await vm.create(title: "   ", body: "\n  ", kind: .misc)

        XCTAssertNil(created, "An all-whitespace draft must not be persisted")
        XCTAssertTrue(vm.notes.isEmpty)
    }

    func testUpdateEditsExistingNoteAndPersists() async throws {
        let vm = NotesViewModel(store: store)
        let created = await vm.create(title: "Draft", body: "v1", kind: .misc)
        let id = try XCTUnwrap(created?.id)

        await vm.update(id: id, title: "Draft", body: "v2", kind: .goal)

        XCTAssertEqual(vm.notes.first?.body, "v2")
        XCTAssertEqual(vm.notes.first?.kind, .goal)
        let persisted = try await store.note(id: id)
        XCTAssertEqual(persisted?.body, "v2")
        XCTAssertEqual(persisted?.kind, .goal)
    }

    func testDeleteRemovesNoteFromListAndStore() async throws {
        let vm = NotesViewModel(store: store)
        let created = await vm.create(title: "Bye", body: "", kind: .misc)
        let id = try XCTUnwrap(created?.id)

        await vm.delete(id: id)

        XCTAssertTrue(vm.notes.isEmpty)
        let persisted = try await store.note(id: id)
        XCTAssertNil(persisted)
    }

    func testOrderingMostRecentFirst() async throws {
        try await store.upsert(Note(title: "Old", body: "", updatedAt: Date(timeIntervalSince1970: 1_000)))
        try await store.upsert(Note(title: "New", body: "", updatedAt: Date(timeIntervalSince1970: 2_000)))

        let vm = NotesViewModel(store: store)
        await vm.load()

        XCTAssertEqual(vm.notes.map(\.title), ["New", "Old"])
    }
}
