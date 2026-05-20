import XCTest
import UIKit
@testable import WeeklyPlanner

@MainActor
final class GoogleAuthServiceTests: XCTestCase {
    private var serviceID: String!
    private var keychain: TokenKeychainStore<GoogleAccountInfo>!
    private var fakeClient: FakeGIDSigningClient!
    private var sut: LiveGoogleAuthService!

    override func setUp() async throws {
        try await super.setUp()
        serviceID = "com.weeklyplanner.tests.\(UUID().uuidString)"
        keychain = TokenKeychainStore<GoogleAccountInfo>(serviceID: serviceID)
        try keychain.clear()
        fakeClient = FakeGIDSigningClient()
        sut = LiveGoogleAuthService(
            config: GoogleAuthConfig(clientID: "test-client-id"),
            client: fakeClient,
            keychain: keychain
        )
    }

    override func tearDown() async throws {
        try? keychain.clear()
        try await super.tearDown()
    }

    func testSignInPersistsTokensInKeychain() async throws {
        let presenter = UIViewController()
        let result = try await sut.signIn(presenting: presenter)

        XCTAssertEqual(result.email, "sara@gmail.com")
        let stored = try keychain.load()
        XCTAssertEqual(stored, result)
        XCTAssertEqual(fakeClient.signInCount, 1)
    }

    func testSignInFailurePropagatesAndDoesNotStore() async throws {
        fakeClient.signInResult = .failure(GoogleAuthError.userCancelled)
        let presenter = UIViewController()

        do {
            _ = try await sut.signIn(presenting: presenter)
            XCTFail("Expected throw")
        } catch GoogleAuthError.userCancelled {
            // expected
        }

        XCTAssertNil(try keychain.load())
    }

    func testSignOutClearsKeychainAndSDK() async throws {
        _ = try await sut.signIn(presenting: UIViewController())
        XCTAssertNotNil(try keychain.load())

        await sut.signOut()

        XCTAssertNil(try keychain.load())
        XCTAssertEqual(fakeClient.signOutCount, 1)
    }

    func testAccessTokenReturnsCachedWhenFresh() async throws {
        _ = try await sut.signIn(presenting: UIViewController())
        let token = try await sut.accessToken()
        XCTAssertEqual(token, "stub-access-token")
        XCTAssertEqual(fakeClient.refreshCount, 0)
    }

    func testAccessTokenRefreshesWhenExpiringSoon() async throws {
        fakeClient.signInResult = .success(.init(
            email: "sara@gmail.com",
            accessToken: "old-token",
            refreshToken: "r",
            expiresAt: Date(timeIntervalSinceNow: 60) // 1 min from now → triggers refresh
        ))
        fakeClient.refreshResult = .success(.init(
            email: "sara@gmail.com",
            accessToken: "new-token",
            refreshToken: "r",
            expiresAt: Date(timeIntervalSinceNow: 3600)
        ))
        _ = try await sut.signIn(presenting: UIViewController())

        let token = try await sut.accessToken()

        XCTAssertEqual(token, "new-token")
        XCTAssertEqual(fakeClient.refreshCount, 1)
        XCTAssertEqual(try keychain.load()?.accessToken, "new-token")
    }

    func testNotConfiguredThrowsWhenClientIDEmpty() async throws {
        sut = LiveGoogleAuthService(
            config: GoogleAuthConfig(clientID: ""),
            client: fakeClient,
            keychain: keychain
        )

        do {
            _ = try await sut.signIn(presenting: UIViewController())
            XCTFail("Expected throw")
        } catch GoogleAuthError.notConfigured {
            // expected
        }

        XCTAssertEqual(fakeClient.signInCount, 0) // SDK never touched
    }

    func testCurrentAccountReadsFromKeychain() async throws {
        _ = try await sut.signIn(presenting: UIViewController())
        let account = sut.currentAccount()
        XCTAssertEqual(account?.email, "sara@gmail.com")
    }
}

// MARK: - Test double

@MainActor
final class FakeGIDSigningClient: GIDSigningClient {
    var signInResult: Result<GoogleAccountInfo, Error> = .success(.init(
        email: "sara@gmail.com",
        accessToken: "stub-access-token",
        refreshToken: "stub-refresh-token",
        expiresAt: Date(timeIntervalSinceNow: 3600)
    ))
    var refreshResult: Result<GoogleAccountInfo, Error> = .failure(GoogleAuthError.reauthenticationRequired)

    private(set) var configureCount = 0
    private(set) var signInCount = 0
    private(set) var refreshCount = 0
    private(set) var signOutCount = 0
    private(set) var handleCount = 0
    private(set) var currentSnapshotCount = 0

    func configure(clientID _: String) { configureCount += 1 }

    func signIn(presenting _: UIViewController, scopes _: [String]) async throws -> GoogleAccountInfo {
        signInCount += 1
        return try signInResult.get()
    }

    func refresh() async throws -> GoogleAccountInfo {
        refreshCount += 1
        return try refreshResult.get()
    }

    func handle(url _: URL) -> Bool { handleCount += 1; return true }
    func signOut() { signOutCount += 1 }
    func currentSnapshot() -> GoogleAccountInfo? { currentSnapshotCount += 1; return nil }
}
