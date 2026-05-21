import Foundation
import UIKit

/// The authentication surface the UI calls into. Production wires
/// `LiveGoogleAuthService`; previews and `ConnectionsViewModelTests` wire
/// `StubGoogleAuthService`.
@MainActor
protocol GoogleAuthService: AnyObject {
    /// Presents the OAuth sheet and returns the freshly-signed-in account.
    /// Throws `GoogleAuthError.userCancelled` if the user dismisses.
    func signIn(presenting: UIViewController) async throws -> GoogleAccountInfo

    /// Revokes the current session and clears the Keychain slot.
    func signOut() async

    /// Returns the cached account, or `nil` if signed-out.
    func currentAccount() -> GoogleAccountInfo?

    /// Returns a valid access token, refreshing if `expiresAt` is within five
    /// minutes of `now`. Throws `.reauthenticationRequired` if the refresh
    /// token itself is rejected.
    func accessToken() async throws -> String
}

/// Canned `GoogleAuthService` used by previews, `ConnectionsViewModelTests`,
/// and as the runtime fallback when `GoogleAuthConfig` reports the client ID
/// is missing. Holds a single in-memory `GoogleAccountInfo` and records call
/// counts so tests can assert orchestration.
@MainActor
final class StubGoogleAuthService: GoogleAuthService {
    /// What `signIn(presenting:)` returns on success. Default is a fixed
    /// `sara@gmail.com` account expiring far in the future.
    var nextSignInResult: Result<GoogleAccountInfo, Error>

    /// In-memory cache of the "current" account; mutated by `signIn` and
    /// `signOut`.
    private(set) var stored: GoogleAccountInfo?

    /// Counters tests can read.
    private(set) var signInCount = 0
    private(set) var signOutCount = 0
    private(set) var accessTokenCount = 0

    nonisolated init() {
        nextSignInResult = .success(.init(
            email: "sara@gmail.com",
            accessToken: "stub-access-token",
            refreshToken: "stub-refresh-token",
            expiresAt: Date(timeIntervalSinceNow: 3600)
        ))
    }

    func signIn(presenting _: UIViewController) async throws -> GoogleAccountInfo {
        signInCount += 1
        let info = try nextSignInResult.get()
        stored = info
        return info
    }

    func signOut() async {
        signOutCount += 1
        stored = nil
    }

    func currentAccount() -> GoogleAccountInfo? {
        stored
    }

    func accessToken() async throws -> String {
        accessTokenCount += 1
        guard let stored else { throw GoogleAuthError.reauthenticationRequired }
        return stored.accessToken
    }
}
