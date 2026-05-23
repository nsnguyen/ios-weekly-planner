import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class PaperEventSheetEditTests: XCTestCase {
    private var container: ModelContainer!
    private var eventStore: SwiftDataEventStore!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        eventStore = SwiftDataEventStore(context: container.mainContext)
    }

    override func tearDown() async throws {
        eventStore = nil
        container = nil
        try await super.tearDown()
    }

    func testEditMode_saveUpdatesExistingEvent() async throws {
        let event = Event(title: "Lunch",
                          start: Date(timeIntervalSince1970: 1_780_000_000),
                          end: Date(timeIntervalSince1970: 1_780_003_600),
                          category: .personal)
        try await eventStore.upsert(event)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore)
        await vm.load()
        vm.beginEditing()
        vm.composer?.title = "Lunch with Jamie"
        await vm.save()

        let reloaded = try await eventStore.event(id: event.id)
        XCTAssertEqual(reloaded?.title, "Lunch with Jamie")
        XCTAssertNil(vm.composer)
    }

    func testCancelWithDirtyComposer_isDirtyDetected() async throws {
        let event = Event(title: "Lunch",
                          start: Date(timeIntervalSince1970: 1_780_000_000),
                          end: Date(timeIntervalSince1970: 1_780_003_600),
                          category: .personal)
        try await eventStore.upsert(event)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore)
        await vm.load()
        vm.beginEditing()
        XCTAssertFalse(vm.composerIsDirty)
        vm.composer?.title = "Renamed"
        XCTAssertTrue(vm.composerIsDirty)
        vm.cancelEditing()
        XCTAssertNil(vm.composer)
    }

    func testCanSave_falseWhenTitleEmptyOrTimesInvalid() async throws {
        let vm = EventDetailViewModel(eventID: UUID(), eventStore: eventStore)
        vm.beginCreating(at: Date(), calendar: WeekMath.mondayCalendar())
        XCTAssertFalse(vm.composer?.canSave ?? true)
        vm.composer?.title = "Lunch"
        XCTAssertTrue(vm.composer?.canSave ?? false)
        vm.composer?.end = vm.composer!.start.addingTimeInterval(-60)
        XCTAssertFalse(vm.composer?.canSave ?? true)
    }

    /// After Save in promoted-edit mode, the sheet flips back to view
    /// instead of dismissing. The VM invariant the sheet relies on is:
    /// composer cleared AND event still loaded with the updated title,
    /// so the view-mode body can render without a re-fetch.
    func testEdit_saveCommitsThenLeavesViewModelInViewableState() async throws {
        let event = Event(title: "Lunch",
                          start: Date(timeIntervalSince1970: 1_780_000_000),
                          end: Date(timeIntervalSince1970: 1_780_003_600),
                          category: .personal)
        try await eventStore.upsert(event)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore)
        await vm.load()
        vm.beginEditing()
        vm.composer?.title = "Lunch with Jamie"
        await vm.save()

        XCTAssertNil(vm.composer)
        XCTAssertEqual(vm.event?.title, "Lunch with Jamie")
    }

    /// After Cancel in promoted-edit mode, the sheet flips back to view
    /// showing the ORIGINAL data — the VM must clear the composer
    /// without touching the loaded event.
    func testEdit_cancelEditingClearsComposerWithoutTouchingEvent() async throws {
        let event = Event(title: "Lunch",
                          start: Date(timeIntervalSince1970: 1_780_000_000),
                          end: Date(timeIntervalSince1970: 1_780_003_600),
                          category: .personal)
        try await eventStore.upsert(event)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore)
        await vm.load()
        vm.beginEditing()
        vm.composer?.title = "Renamed in memory only"

        vm.cancelEditing()

        XCTAssertNil(vm.composer)
        XCTAssertEqual(vm.event?.title, "Lunch")
    }
}
