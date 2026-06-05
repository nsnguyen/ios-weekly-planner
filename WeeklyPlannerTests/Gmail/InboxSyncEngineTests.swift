import XCTest
import SwiftData
@testable import WeeklyPlanner

@MainActor
final class InboxSyncEngineTests: XCTestCase {
    private var container: ModelContainer!
    private var settingsStore: SwiftDataSettingsStore!
    private var inboxStore: SwiftDataInboxStore!
    private var fakeClient: FakeGmailClient!
    private var fakeExtractor: FakeEventExtractor!
    private var sut: InboxSyncEngine!

    override func setUp() async throws {
        try await super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: UserSettings.self, InboxSuggestion.self, Event.self, TaskItem.self,
            configurations: config
        )
        settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        inboxStore = SwiftDataInboxStore(context: container.mainContext)
        fakeClient = FakeGmailClient()
        fakeExtractor = FakeEventExtractor()
        sut = InboxSyncEngine(
            client: fakeClient,
            extractor: fakeExtractor,
            inboxStore: inboxStore,
            deltaSync: GmailDeltaSync(settingsStore: settingsStore)
        )
    }

    func testInitialFullSyncInsertsSuggestions() async throws {
        fakeClient.listResponse = [GmailMessageStub(id: "m1", threadId: nil)]
        fakeClient.messageResponses["m1"] = makeMessage(id: "m1", subject: "Reservation at Café Bleu", from: "Resy <reservations@resy.com>")
        fakeExtractor.nextResult = futureExtractedEvent(title: "Dinner at Café Bleu")
        fakeClient.profileResponse = GmailProfile(emailAddress: "u@x.com", historyId: "100", messagesTotal: 1)

        let result = try await sut.sync(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(result.added, 1)
        // suggestion startISO is 2026-06-12T19:00:00Z; query pending for that week
        let suggestionDate = ISO8601DateFormatter().date(from: "2026-06-12T19:00:00Z")!
        let stored = try await inboxStore.pending(forWeekOffset: 0, today: suggestionDate)
        XCTAssertEqual(stored.first?.title, "Dinner at Café Bleu")
        XCTAssertEqual(try settingsStore.current().gmailLastHistoryId, "100")
    }

    func testDeltaSyncOnlyProcessesNewMessages() async throws {
        try settingsStore.update { $0.gmailLastHistoryId = "50" }
        try await inboxStore.upsert(makeSuggestion(id: "m1"))

        fakeClient.historyResponse = GmailHistoryResponse(
            history: [GmailHistoryRecord(id: "51", messages: nil, messagesAdded: [
                GmailMessageAdded(message: GmailMessageStub(id: "m2", threadId: nil)),
            ])],
            nextPageToken: nil,
            historyId: "51"
        )
        fakeClient.messageResponses["m2"] = makeMessage(id: "m2", subject: "Tickets for the show", from: "Ticketmaster <noreply@ticketmaster.com>")
        fakeExtractor.nextResult = futureExtractedEvent(title: "Show")
        fakeClient.profileResponse = GmailProfile(emailAddress: "u@x.com", historyId: "51", messagesTotal: 1)

        let result = try await sut.sync(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(fakeClient.messageFetchCalls, ["m2"])
    }

    func testAcceptedSuggestionCreatesEventThroughStore() async throws {
        let inMemoryEvents = InMemoryEventStore()
        let storeWithEvents = SwiftDataInboxStore(
            context: container.mainContext,
            eventStore: inMemoryEvents,
            settingsStore: settingsStore
        )
        try await storeWithEvents.upsert(makeSuggestion(id: "m1"))
        let id = try await storeWithEvents.pending(
            forWeekOffset: 0,
            today: Date(timeIntervalSince1970: 1_700_000_000)
        ).first!.id

        try await storeWithEvents.accept(id: id)

        XCTAssertEqual(inMemoryEvents.upsertedEvents.count, 1)
        XCTAssertEqual(inMemoryEvents.upsertedEvents.first?.source, .gmail)
    }

    func testDismissPreventsResuggestionOnNextSync() async throws {
        try await inboxStore.upsert(makeSuggestion(id: "m1"))
        let id = try await inboxStore.pending(forWeekOffset: 0, today: Date(timeIntervalSince1970: 1_700_000_000)).first!.id
        try await inboxStore.dismiss(id: id)

        fakeClient.listResponse = [GmailMessageStub(id: "m1", threadId: nil)]
        fakeClient.messageResponses["m1"] = makeMessage(id: "m1", subject: "Reservation at Café Bleu", from: "Resy <reservations@resy.com>")
        fakeExtractor.nextResult = futureExtractedEvent(title: "Dinner again")
        fakeClient.profileResponse = GmailProfile(emailAddress: "u@x.com", historyId: "100", messagesTotal: 1)

        let result = try await sut.sync(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(result.added, 0)
    }

    func testPastDatedSuggestionSkipped() async throws {
        fakeClient.listResponse = [GmailMessageStub(id: "m1", threadId: nil)]
        fakeClient.messageResponses["m1"] = makeMessage(id: "m1", subject: "Yesterday's event", from: "x <x@y.com>")
        fakeExtractor.nextResult = ExtractedEvent(
            isEvent: true, title: "Yesterday",
            startISO: "2025-01-01T10:00:00Z",
            endISO: "", location: "", categoryHint: "", confidence: 0.9
        )
        fakeClient.profileResponse = GmailProfile(emailAddress: "u@x.com", historyId: "100", messagesTotal: 1)

        let result = try await sut.sync(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(result.added, 0)
    }

    func testSingleFlightQueuesSecondCall() async throws {
        fakeClient.listResponse = []
        fakeClient.profileResponse = GmailProfile(emailAddress: "u@x.com", historyId: "100", messagesTotal: 0)

        let engine = sut!
        let client = fakeClient!
        let now = Date()
        async let a: SyncResult = engine.sync(now: now)
        async let b: SyncResult = engine.sync(now: now)
        _ = try await a
        _ = try await b

        XCTAssertLessThanOrEqual(client.maxConcurrentCalls, 1)
    }

    // MARK: - Fixtures

    private func makeMessage(id: String, subject: String, from: String) -> GmailMessage {
        GmailMessage(
            id: id,
            threadId: nil,
            snippet: subject,
            historyId: nil,
            internalDate: nil,
            payload: GmailPayload(
                mimeType: "text/plain",
                headers: [
                    GmailHeader(name: "Subject", value: subject),
                    GmailHeader(name: "From", value: from),
                ],
                body: nil,
                parts: nil
            )
        )
    }

    private func makeSuggestion(id: String) -> InboxSuggestion {
        InboxSuggestion(
            gmailMessageID: id,
            proposedStart: Date(timeIntervalSince1970: 1_700_050_000),
            title: "Existing",
            fromName: "Resy",
            fromEmail: "reservations@resy.com",
            subject: "Existing",
            bodySnippet: nil
        )
    }

    private func futureExtractedEvent(title: String) -> ExtractedEvent {
        ExtractedEvent(
            isEvent: true,
            title: title,
            startISO: "2026-06-12T19:00:00Z",
            endISO: "",
            location: "Café Bleu",
            categoryHint: "",
            confidence: 0.9
        )
    }
}

// MARK: - Test doubles

@MainActor
final class FakeGmailClient: GmailClientProtocol {
    var listResponse: [GmailMessageStub] = []
    var messageResponses: [String: GmailMessage] = [:]
    var historyResponse: GmailHistoryResponse?
    var profileResponse: GmailProfile = GmailProfile(emailAddress: "x@y.com", historyId: "0", messagesTotal: 0)
    private(set) var messageFetchCalls: [String] = []
    private(set) var maxConcurrentCalls = 0
    private var currentCalls = 0

    nonisolated init() {}

    func listMessages(query _: String, maxResults _: Int) async throws -> [GmailMessageStub] {
        try await trackingCall { self.listResponse }
    }

    func fetchMessage(id: String, format _: GmailMessageFormat) async throws -> GmailMessage {
        try await trackingCall {
            self.messageFetchCalls.append(id)
            guard let m = self.messageResponses[id] else { throw GmailClientError.http(status: 404) }
            return m
        }
    }

    func history(startHistoryId _: String) async throws -> GmailHistoryResponse {
        try await trackingCall {
            guard let h = self.historyResponse else { throw GmailClientError.historyExpired }
            return h
        }
    }

    func profile() async throws -> GmailProfile {
        try await trackingCall { self.profileResponse }
    }

    private func trackingCall<T>(_ body: @escaping () throws -> T) async throws -> T {
        currentCalls += 1
        maxConcurrentCalls = max(maxConcurrentCalls, currentCalls)
        defer { currentCalls -= 1 }
        return try body()
    }
}

@MainActor
final class InMemoryEventStore: EventStoring {
    private(set) var upsertedEvents: [Event] = []
    nonisolated init() {}
    func events(forWeekOffset _: Int, today _: Date) async throws -> [Event] { [] }
    func event(id _: UUID) async throws -> Event? { nil }
    func upsert(_ event: Event) async throws { upsertedEvents.append(event) }
    func delete(id _: UUID) async throws {}
    func deleteOccurrence(eventID _: UUID, occurrenceStart _: Date) async throws {}
    func events(matching _: EventQuery) async throws -> [Event] { [] }
}
