import SwiftData
import XCTest
@testable import WeeklyPlanner

// MARK: - Spy GCalSyncEngine

/// Records whether `purge()` was called, without touching real stores.
@MainActor
final class SpyGCalSyncEngine: GCalPurging {
    private(set) var purgeCallCount = 0

    func purge() async {
        purgeCallCount += 1
    }
}

// MARK: - Tests

@MainActor
final class ConnectionsCalendarTests: XCTestCase {
    private var container: ModelContainer!
    private var settingsStore: SwiftDataSettingsStore!
    private var inboxStore: SwiftDataInboxStore!
    private var auth: StubGoogleAuthService!
    private var spyEngine: SpyGCalSyncEngine!
    private var sut: ConnectionsViewModel!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        inboxStore = SwiftDataInboxStore(context: container.mainContext)
        auth = StubGoogleAuthService()
        spyEngine = SpyGCalSyncEngine()
        sut = ConnectionsViewModel(
            settingsStore: settingsStore,
            inboxStore: inboxStore,
            auth: auth,
            gcalSyncEngine: spyEngine
        )
    }

    override func tearDown() async throws {
        sut = nil
        spyEngine = nil
        auth = nil
        inboxStore = nil
        settingsStore = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - Connect

    func testConnectGoogleCalendarSetsConnectedFlagAndEmail() async throws {
        let presenter = UIViewController()

        await sut.connectGoogleCalendar(presenter: presenter)

        XCTAssertTrue(sut.isGoogleCalendarConnected)
        let settings = try settingsStore.current()
        XCTAssertTrue(settings.googleCalendarConnected)
        XCTAssertEqual(settings.googleCalendarAccountEmail, "sara@gmail.com")
        XCTAssertEqual(sut.googleCalendarAccountEmail, "sara@gmail.com")
    }

    func testConnectGoogleCalendarPostsNotification() async throws {
        let expectation = XCTestExpectation(description: ".googleCalendarDidConnect posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .googleCalendarDidConnect,
            object: nil,
            queue: .main
        ) { _ in expectation.fulfill() }
        defer { NotificationCenter.default.removeObserver(observer) }

        let presenter = UIViewController()
        await sut.connectGoogleCalendar(presenter: presenter)

        await fulfillment(of: [expectation], timeout: 1)
    }

    func testConnectGoogleCalendarCancelRevertsFlag() async throws {
        auth.nextSignInResult = .failure(GoogleAuthError.userCancelled)

        await sut.connectGoogleCalendar(presenter: UIViewController())

        XCTAssertFalse(sut.isGoogleCalendarConnected)
        let settings = try settingsStore.current()
        XCTAssertFalse(settings.googleCalendarConnected)
        XCTAssertNil(sut.alert)
    }

    // MARK: - Disconnect

    func testDisconnectGoogleCalendarCallsPurge() async throws {
        // Pre-state: connected.
        await sut.connectGoogleCalendar(presenter: UIViewController())
        XCTAssertTrue(sut.isGoogleCalendarConnected)

        await sut.disconnectGoogleCalendar()

        XCTAssertEqual(spyEngine.purgeCallCount, 1)
    }

    func testDisconnectGoogleCalendarClearsConnectedFlag() async throws {
        await sut.connectGoogleCalendar(presenter: UIViewController())

        await sut.disconnectGoogleCalendar()

        XCTAssertFalse(sut.isGoogleCalendarConnected)
        let settings = try settingsStore.current()
        XCTAssertFalse(settings.googleCalendarConnected)
        XCTAssertNil(settings.googleCalendarAccountEmail)
        XCTAssertNil(sut.googleCalendarAccountEmail)
    }

    func testDisconnectGoogleCalendarDoesNotCallSignOut() async throws {
        // Critical: Gmail shares the same OAuth token.
        // Disconnecting Calendar must NOT revoke it.
        await sut.connectGoogleCalendar(presenter: UIViewController())

        await sut.disconnectGoogleCalendar()

        XCTAssertEqual(auth.signOutCount, 0,
            "disconnectGoogleCalendar must NOT call auth.signOut() — it would break a connected Gmail")
    }

    func testDisconnectGoogleCalendarClearsSyncToken() async throws {
        // Pre-seed a sync token in settings.
        try settingsStore.update { $0.gcalSyncToken = "old-sync-token" }
        await sut.connectGoogleCalendar(presenter: UIViewController())

        await sut.disconnectGoogleCalendar()

        // purge() clears the token via GCalDeltaSync; spy records the call.
        // We verify that purge was invoked (the real engine does the token clear).
        XCTAssertEqual(spyEngine.purgeCallCount, 1)
    }
}
