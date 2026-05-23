import CoreLocation
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventDetailViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var eventStore: SwiftDataEventStore!
    private var fakeGeocoder: FakeGeocoder!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        eventStore = SwiftDataEventStore(context: container.mainContext)
        fakeGeocoder = FakeGeocoder()
    }

    override func tearDown() async throws {
        fakeGeocoder = nil
        eventStore = nil
        container = nil
        try await super.tearDown()
    }

    func testToggleAlertAddsTimeBeforeReminder() async throws {
        let event = Event(title: "Standup",
                          start: .init(),
                          end: .init().addingTimeInterval(3600),
                          category: .work)
        try await eventStore.upsert(event)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore, geocoder: fakeGeocoder)
        await vm.load()
        XCTAssertFalse(vm.alertOn)

        await vm.toggleAlert(true)
        let reloaded = try await eventStore.event(id: event.id)
        let hasTimeBefore = reloaded?.reminders.contains {
            if case .timeBefore = $0 { true } else { false }
        } ?? false
        XCTAssertTrue(hasTimeBefore)
        XCTAssertTrue(vm.alertOn)
    }

    func testToggleAlertOffRemovesTimeBeforeReminder() async throws {
        let event = Event(title: "Standup",
                          start: .init(),
                          end: .init(),
                          category: .work,
                          reminders: [.timeBefore(minutes: 15)])
        try await eventStore.upsert(event)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore, geocoder: fakeGeocoder)
        await vm.load()
        XCTAssertTrue(vm.alertOn)

        await vm.toggleAlert(false)
        let reloaded = try await eventStore.event(id: event.id)
        let stillHasTimeBefore = reloaded?.reminders.contains {
            if case .timeBefore = $0 { true } else { false }
        } ?? true
        XCTAssertFalse(stillHasTimeBefore)
    }

    func testToggleLocationAlertGeocodesLocation() async throws {
        let event = Event(title: "Lunch",
                          start: .init(),
                          end: .init(),
                          location: "Marina",
                          category: .personal)
        try await eventStore.upsert(event)
        fakeGeocoder.next = CLLocationCoordinate2D(latitude: 37.81, longitude: -122.45)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore, geocoder: fakeGeocoder)
        await vm.load()

        await vm.toggleLocationAlert(true)
        XCTAssertTrue(vm.locationAlertOn)
        XCTAssertNotNil(vm.cachedCoordinate)
        let reloaded = try await eventStore.event(id: event.id)
        let hasOnArrive = reloaded?.reminders.contains {
            if case .onArrive = $0 { true } else { false }
        } ?? false
        XCTAssertTrue(hasOnArrive)
    }

    func testToggleLocationAlertWithoutLocationIsNoOp() async throws {
        let event = Event(title: "Standup",
                          start: .init(),
                          end: .init(),
                          category: .work)
        try await eventStore.upsert(event)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore, geocoder: fakeGeocoder)
        await vm.load()

        await vm.toggleLocationAlert(true)
        XCTAssertFalse(vm.locationAlertOn)
    }

    func testDeleteRemovesEventFromStore() async throws {
        let event = Event(title: "Doomed",
                          start: .init(),
                          end: .init(),
                          category: .personal)
        try await eventStore.upsert(event)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore, geocoder: fakeGeocoder)
        await vm.load()
        await vm.delete()

        let after = try await eventStore.event(id: event.id)
        XCTAssertNil(after)
    }

    func testAISuggestionForBirthdayEvent() async throws {
        let event = Event(title: "Sara's birthday breakfast",
                          start: .init(),
                          end: .init(),
                          category: .personal)
        try await eventStore.upsert(event)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore, geocoder: fakeGeocoder)
        await vm.load()
        XCTAssertTrue(vm.aiSuggestion.contains("Uber") || vm.aiSuggestion.contains("Trick Dog"))
    }

    func testSaveCommitsComposerDraft() async throws {
        let event = Event(title: "Old title",
                          start: Date(timeIntervalSince1970: 1_780_000_000),
                          end: Date(timeIntervalSince1970: 1_780_003_600),
                          category: .work)
        try await eventStore.upsert(event)

        let vm = EventDetailViewModel(eventID: event.id, eventStore: eventStore, geocoder: fakeGeocoder)
        await vm.load()
        vm.beginEditing()
        XCTAssertNotNil(vm.composer)

        vm.composer?.title = "New title"
        vm.composer?.category = .health
        await vm.save()

        let reloaded = try await eventStore.event(id: event.id)
        XCTAssertEqual(reloaded?.title, "New title")
        XCTAssertEqual(reloaded?.category, .health)
        XCTAssertNil(vm.composer, "composer should clear after a successful save")
    }

    func testSaveInCreateModeUpsertsBrandNewEvent() async throws {
        let vm = EventDetailViewModel(eventID: UUID(),
                                      eventStore: eventStore,
                                      geocoder: fakeGeocoder)
        vm.beginCreating(at: Date(timeIntervalSince1970: 1_780_000_000),
                         calendar: WeekMath.mondayCalendar())
        vm.composer?.title = "Lunch with Jamie"
        await vm.save()

        let all = try await eventStore.events(forWeekOffset: 0,
                                              today: Date(timeIntervalSince1970: 1_780_000_000))
        XCTAssertEqual(all.filter { $0.title == "Lunch with Jamie" }.count, 1)
    }
}

/// Test-only geocoder that returns a canned coordinate or throws a canned
/// error. `@unchecked Sendable` is acceptable because every test runs
/// serially and only the main-actor test methods touch the storage.
final class FakeGeocoder: AddressGeocoding, @unchecked Sendable {
    var next: CLLocationCoordinate2D?
    var nextError: Error?

    init() {}

    func geocode(address _: String) async throws -> CLLocationCoordinate2D {
        if let nextError { throw nextError }
        guard let next else { throw NSError(domain: "Fake", code: -1) }
        return next
    }
}
