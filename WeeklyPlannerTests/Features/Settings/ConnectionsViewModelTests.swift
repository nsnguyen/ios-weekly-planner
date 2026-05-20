import XCTest
import SwiftData
@testable import WeeklyPlanner

@MainActor
final class ConnectionsViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var settingsStore: SwiftDataSettingsStore!
    private var inboxStore: SwiftDataInboxStore!
    private var auth: StubGoogleAuthService!
    private var sut: ConnectionsViewModel!

    override func setUp() async throws {
        try await super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: UserSettings.self, InboxSuggestion.self, Event.self, TaskItem.self,
            configurations: config
        )
        settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        inboxStore = SwiftDataInboxStore(context: container.mainContext)
        auth = StubGoogleAuthService()
        sut = ConnectionsViewModel(
            settingsStore: settingsStore,
            inboxStore: inboxStore,
            auth: auth
        )
    }

    // MARK: - Connect

    func testConnectHappyPathSetsConnectedFlagAndEmail() async throws {
        let presenter = await MainActor.run { UIViewController() }

        await sut.connectGmail(presenter: presenter)

        let settings = try settingsStore.current()
        XCTAssertTrue(settings.gmailConnected)
        XCTAssertEqual(settings.gmailAccountEmail, "sara@gmail.com")
        XCTAssertTrue(sut.isGmailConnected)
        XCTAssertNil(sut.alert)
    }

    func testConnectCancelRevertsOptimisticFlag() async throws {
        auth.nextSignInResult = .failure(GoogleAuthError.userCancelled)
        let presenter = await MainActor.run { UIViewController() }

        await sut.connectGmail(presenter: presenter)

        let settings = try settingsStore.current()
        XCTAssertFalse(settings.gmailConnected)
        XCTAssertNil(settings.gmailAccountEmail)
        XCTAssertFalse(sut.isGmailConnected)
        // cancel is silent — no alert
        XCTAssertNil(sut.alert)
    }

    func testConnectNetworkFailureShowsAlert() async throws {
        auth.nextSignInResult = .failure(GoogleAuthError.network("timeout"))
        let presenter = await MainActor.run { UIViewController() }

        await sut.connectGmail(presenter: presenter)

        XCTAssertFalse(sut.isGmailConnected)
        XCTAssertNotNil(sut.alert)
        XCTAssertEqual(sut.alert?.title, "Couldn't connect Gmail")
    }

    func testConnectNotConfiguredShowsHelpfulAlert() async throws {
        auth.nextSignInResult = .failure(GoogleAuthError.notConfigured)
        let presenter = await MainActor.run { UIViewController() }

        await sut.connectGmail(presenter: presenter)

        XCTAssertFalse(sut.isGmailConnected)
        XCTAssertEqual(sut.alert?.title, "Gmail isn't configured")
    }

    // MARK: - Disconnect

    func testDisconnectClearsConnectedFlag() async throws {
        // Pre-state: connected.
        await sut.connectGmail(presenter: UIViewController())
        XCTAssertTrue(try settingsStore.current().gmailConnected)

        await sut.disconnectGmail()

        let settings = try settingsStore.current()
        XCTAssertFalse(settings.gmailConnected)
        XCTAssertNil(settings.gmailAccountEmail)
        XCTAssertEqual(auth.signOutCount, 1)
    }

    func testDisconnectCascadeDeletesPendingSuggestions() async throws {
        await sut.connectGmail(presenter: UIViewController())
        try await inboxStore.upsert(makeSuggestion(id: "msg-1"))
        try await inboxStore.upsert(makeSuggestion(id: "msg-2"))

        await sut.disconnectGmail()

        let remaining = try await inboxStore.pending(
            forWeekOffset: 0,
            today: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: - Helpers

    private func makeSuggestion(id: String) -> InboxSuggestion {
        InboxSuggestion(
            gmailMessageID: id,
            proposedStart: Date(timeIntervalSince1970: 1_700_050_000), // mid-week of the "today" used above
            title: "Lunch with Sara",
            fromName: "Resy",
            fromEmail: "reservations@resy.com",
            subject: "Confirmed: 1pm at Café Bleu",
            bodySnippet: nil
        )
    }
}
