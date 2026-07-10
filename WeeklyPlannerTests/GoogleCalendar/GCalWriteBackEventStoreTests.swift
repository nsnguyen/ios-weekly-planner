import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class GCalWriteBackEventStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var swiftDataStore: SwiftDataEventStore!
    private var settingsStore: SwiftDataSettingsStore!
    private var gateway: FakeEventKitGateway!
    private var client: FakeGoogleCalendarClient!
    private var store: GoogleCalendarWriteBackEventStore!

    private let start = Date(timeIntervalSince1970: 1_749_895_200)
    private let end = Date(timeIntervalSince1970: 1_749_898_800)

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        swiftDataStore = SwiftDataEventStore(context: container.mainContext)
        settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        gateway = FakeEventKitGateway()
        client = FakeGoogleCalendarClient()

        let eventKitStore = EventKitMirroringEventStore(
            base: swiftDataStore,
            gateway: gateway,
            calendarManager: CategoryCalendarManager(gateway: gateway)
        )
        store = GoogleCalendarWriteBackEventStore(
            base: eventKitStore,
            client: client,
            settingsStore: settingsStore
        )
    }

    override func tearDown() async throws {
        store = nil
        client = nil
        gateway = nil
        settingsStore = nil
        swiftDataStore = nil
        container = nil
        try await super.tearDown()
    }

    func testCreateWhileConnectedPostsAndFlipsSource() async throws {
        try settingsStore.update {
            $0.googleCalendarConnected = true
            $0.googleCalendarAccountEmail = "planner@example.com"
        }
        client.createResult = makeRemoteEvent(
            id: "remote-created-1",
            etag: "\"remote-etag\"",
            updated: "2026-06-14T12:34:56.789Z"
        )
        let event = makeLocalEvent(eventKitIdentifier: "ek-local-id")

        try await store.upsert(event)

        XCTAssertEqual(client.created.count, 1)
        XCTAssertEqual(client.created[0].summary, "Write-back meeting")
        XCTAssertTrue(gateway.savedEvents.isEmpty, "Google-sourced event must not be mirrored back into EventKit")

        let storedEvent = try await swiftDataStore.event(id: event.id)
        let fetched = try XCTUnwrap(storedEvent)
        XCTAssertEqual(fetched.googleEventID, "remote-created-1")
        XCTAssertEqual(fetched.googleEtag, "\"remote-etag\"")
        XCTAssertEqual(fetched.source, .googleCalendar)
        XCTAssertNil(fetched.eventKitIdentifier)
        XCTAssertEqual(fetched.updatedAt, try XCTUnwrap(Self.isoWithFractionalSeconds.date(from: "2026-06-14T12:34:56.789Z")))

        XCTAssertEqual(event.googleEventID, "remote-created-1", "Event is a class, so the decorator should mutate in place")
        XCTAssertEqual(event.source, .googleCalendar)
    }

    func testCreateWhileDisconnectedSkipsGoogle() async throws {
        try settingsStore.update {
            $0.googleCalendarConnected = false
            $0.googleCalendarAccountEmail = nil
        }
        let event = makeLocalEvent()

        try await store.upsert(event)

        XCTAssertTrue(client.created.isEmpty)
        XCTAssertFalse(gateway.savedEvents.isEmpty, "Disconnected manual writes should continue through EventKit mirroring")

        let storedEvent = try await swiftDataStore.event(id: event.id)
        let fetched = try XCTUnwrap(storedEvent)
        XCTAssertNil(fetched.googleEventID)
        XCTAssertNil(fetched.googleEtag)
        XCTAssertEqual(fetched.source, .manual)
    }

    func testRecurringCreateDoesNotPush() async throws {
        try settingsStore.update {
            $0.googleCalendarConnected = true
            $0.googleCalendarAccountEmail = "planner@example.com"
        }
        let event = makeLocalEvent(
            recurrence: Recurrence(frequency: .weekly, interval: 1, end: .never)
        )

        try await store.upsert(event)

        XCTAssertTrue(client.created.isEmpty)

        let storedEvent = try await swiftDataStore.event(id: event.id)
        let fetched = try XCTUnwrap(storedEvent)
        XCTAssertNil(fetched.googleEventID)
        XCTAssertEqual(fetched.source, .manual)
        XCTAssertEqual(fetched.recurrence, Recurrence(frequency: .weekly, interval: 1, end: .never))
    }

    func testUpdateLocalNewerPushes() async throws {
        try settingsStore.update {
            $0.googleCalendarConnected = true
            $0.googleCalendarAccountEmail = "planner@example.com"
        }
        let localUpdated = try XCTUnwrap(Self.isoWithFractionalSeconds.date(from: "2026-06-14T13:00:00.250Z"))
        let event = makeLocalEvent(
            title: "Local wins",
            googleEventID: "remote-update-1",
            googleEtag: "\"old-local-etag\"",
            updatedAt: localUpdated
        )
        client.getResponses["remote-update-1"] = makeRemoteEvent(
            id: "remote-update-1",
            title: "Remote older",
            etag: "\"remote-old\"",
            updated: "2026-06-14T12:00:00.125Z"
        )
        client.updateResult = makeRemoteEvent(
            id: "remote-update-1",
            title: "Local wins",
            etag: "\"remote-after-update\"",
            updated: "2026-06-14T13:01:00.500Z"
        )

        try await store.upsert(event)

        XCTAssertEqual(client.updated.count, 1)
        XCTAssertEqual(client.updated[0].id, "remote-update-1")
        XCTAssertEqual(client.updated[0].etag, "\"remote-old\"")
        XCTAssertEqual(client.updated[0].body.summary, "Local wins")

        let storedEvent = try await swiftDataStore.event(id: event.id)
        let fetched = try XCTUnwrap(storedEvent)
        XCTAssertEqual(fetched.title, "Local wins")
        XCTAssertEqual(fetched.googleEtag, "\"remote-after-update\"")
        XCTAssertEqual(fetched.updatedAt, try XCTUnwrap(Self.isoWithFractionalSeconds.date(from: "2026-06-14T13:01:00.500Z")))
    }

    func testUpdateRemoteNewerAppliesRemoteSkipsPush() async throws {
        try settingsStore.update {
            $0.googleCalendarConnected = true
            $0.googleCalendarAccountEmail = "planner@example.com"
        }
        let localUpdated = try XCTUnwrap(Self.isoWithFractionalSeconds.date(from: "2026-06-14T13:00:00.250Z"))
        let event = makeLocalEvent(
            title: "Local edit",
            googleEventID: "remote-update-2",
            googleEtag: "\"stale-local-etag\"",
            updatedAt: localUpdated
        )
        client.getResponses["remote-update-2"] = makeRemoteEvent(
            id: "remote-update-2",
            title: "Remote wins",
            etag: "\"remote-newer\"",
            updated: "2026-06-14T13:30:00.750Z"
        )

        try await store.upsert(event)

        XCTAssertTrue(client.updated.isEmpty)

        let storedEvent = try await swiftDataStore.event(id: event.id)
        let fetched = try XCTUnwrap(storedEvent)
        XCTAssertEqual(fetched.title, "Remote wins")
        XCTAssertEqual(fetched.googleEtag, "\"remote-newer\"")
        XCTAssertEqual(fetched.updatedAt, try XCTUnwrap(Self.isoWithFractionalSeconds.date(from: "2026-06-14T13:30:00.750Z")))
    }

    func testUpdate412RetriesOnce() async throws {
        try settingsStore.update {
            $0.googleCalendarConnected = true
            $0.googleCalendarAccountEmail = "planner@example.com"
        }
        let localUpdated = try XCTUnwrap(Self.isoWithFractionalSeconds.date(from: "2026-06-14T13:00:00.250Z"))
        let event = makeLocalEvent(
            title: "Retry local wins",
            googleEventID: "remote-update-3",
            googleEtag: "\"stale-local-etag\"",
            updatedAt: localUpdated
        )
        client.getResponses["remote-update-3"] = makeRemoteEvent(
            id: "remote-update-3",
            title: "Remote older",
            etag: "\"fresh-remote-etag\"",
            updated: "2026-06-14T12:00:00.125Z"
        )
        client.updateBehavior = [
            .failure(GoogleCalendarClientError.preconditionFailed),
            .success(makeRemoteEvent(
                id: "remote-update-3",
                title: "Retry local wins",
                etag: "\"remote-after-retry\"",
                updated: "2026-06-14T13:02:00.500Z"
            ))
        ]

        try await store.upsert(event)

        XCTAssertEqual(client.updated.count, 2)
        XCTAssertEqual(client.updated[0].etag, "\"fresh-remote-etag\"")
        XCTAssertEqual(client.updated[1].etag, "\"fresh-remote-etag\"")
        XCTAssertEqual(client.updated[1].body.summary, "Retry local wins")

        let storedEvent = try await swiftDataStore.event(id: event.id)
        let fetched = try XCTUnwrap(storedEvent)
        XCTAssertEqual(fetched.title, "Retry local wins")
        XCTAssertEqual(fetched.googleEtag, "\"remote-after-retry\"")
        XCTAssertEqual(fetched.updatedAt, try XCTUnwrap(Self.isoWithFractionalSeconds.date(from: "2026-06-14T13:02:00.500Z")))
    }

    func testDeleteCancelsRemoteThenRemovesLocal() async throws {
        try settingsStore.update {
            $0.googleCalendarConnected = true
            $0.googleCalendarAccountEmail = "planner@example.com"
        }
        let event = makeLocalEvent(
            source: .googleCalendar,
            googleEventID: "remote-delete-1",
            googleEtag: "\"delete-etag\""
        )
        try await swiftDataStore.upsert(event)

        try await store.delete(id: event.id)

        XCTAssertEqual(client.cancelledIDs, ["remote-delete-1"])
        let storedEvent = try await swiftDataStore.event(id: event.id)
        XCTAssertNil(storedEvent)
    }

    func testDeleteNotFoundStillDeletesLocal() async throws {
        try settingsStore.update {
            $0.googleCalendarConnected = true
            $0.googleCalendarAccountEmail = "planner@example.com"
        }
        let event = makeLocalEvent(
            source: .googleCalendar,
            googleEventID: "already-gone",
            googleEtag: "\"delete-etag\""
        )
        try await swiftDataStore.upsert(event)
        client.throwOnWrite = GoogleCalendarClientError.notFound

        try await store.delete(id: event.id)

        let storedEvent = try await swiftDataStore.event(id: event.id)
        XCTAssertNil(storedEvent)
    }

    func testPurgeDoesNotCancelRemote() async throws {
        try settingsStore.update {
            $0.googleCalendarConnected = true
            $0.googleCalendarAccountEmail = "planner@example.com"
        }
        let event = makeLocalEvent(
            source: .googleCalendar,
            googleEventID: "remote-purge-1",
            googleEtag: "\"purge-etag\""
        )
        try await swiftDataStore.upsert(event)

        try await GCalWriteBackContext.$suppressWriteBack.withValue(true) {
            try await store.delete(id: event.id)
        }

        XCTAssertTrue(client.cancelledIDs.isEmpty)
        let storedEvent = try await swiftDataStore.event(id: event.id)
        XCTAssertNil(storedEvent)
    }

    func testSyncUpsertDoesNotEchoCreate() async throws {
        try settingsStore.update {
            $0.googleCalendarConnected = true
            $0.googleCalendarAccountEmail = "planner@example.com"
        }
        let event = makeLocalEvent(
            source: .googleCalendar,
            googleEventID: "remote-import-1",
            googleEtag: "\"import-etag\""
        )

        try await GCalWriteBackContext.$suppressWriteBack.withValue(true) {
            try await store.upsert(event)
        }

        XCTAssertTrue(client.created.isEmpty)
        XCTAssertTrue(client.updated.isEmpty)
        let storedEvent = try await swiftDataStore.event(id: event.id)
        let fetched = try XCTUnwrap(storedEvent)
        XCTAssertEqual(fetched.googleEventID, "remote-import-1")
    }

    private func makeLocalEvent(
        title: String = "Write-back meeting",
        eventKitIdentifier: String? = nil,
        source: EventSource = .manual,
        googleEventID: String? = nil,
        googleEtag: String? = nil,
        updatedAt: Date = .init(),
        recurrence: Recurrence? = nil
    ) -> Event {
        Event(
            eventKitIdentifier: eventKitIdentifier,
            title: title,
            start: start,
            end: end,
            location: "Conference Room",
            notes: "Discuss calendar write-back",
            category: .work,
            source: source,
            googleEventID: googleEventID,
            googleEtag: googleEtag,
            recurrence: recurrence,
            updatedAt: updatedAt
        )
    }

    private func makeRemoteEvent(
        id: String,
        title: String = "Write-back meeting",
        etag: String?,
        updated: String?
    ) -> GCalEvent {
        GCalEvent(
            id: id,
            status: "confirmed",
            summary: title,
            location: "Conference Room",
            description: "Discuss calendar write-back",
            start: GCalDateTime(date: nil, dateTime: Self.iso.string(from: start)),
            end: GCalDateTime(date: nil, dateTime: Self.iso.string(from: end)),
            etag: etag,
            updated: updated
        )
    }

    private nonisolated(unsafe) static let iso = ISO8601DateFormatter()
    private nonisolated(unsafe) static let isoWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
