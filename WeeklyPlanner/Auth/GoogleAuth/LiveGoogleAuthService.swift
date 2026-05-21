import Foundation
import UIKit

/// Production `GoogleAuthService`. Composes:
/// - `GoogleAuthConfig` (the client ID from Info.plist),
/// - `GIDSigningClient` (the SDK seam — `RealGIDSigningClient` in production,
///   `FakeGIDSigningClient` in tests),
/// - `TokenKeychainStore<GoogleAccountInfo>` (encrypted local cache).
///
/// On init, calls `client.configure(clientID:)` once so `GIDSignIn` knows
/// which app it's signing in for. Subsequent `signIn` calls use that config.
@MainActor
final class LiveGoogleAuthService: GoogleAuthService {
    private let config: GoogleAuthConfig
    private let client: GIDSigningClient
    private let keychain: TokenKeychainStore<GoogleAccountInfo>
    private let scopes = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/userinfo.email",
    ]
    private static let refreshLeeway: TimeInterval = 5 * 60 // refresh when <5 min remain

    init(
        config: GoogleAuthConfig,
        client: GIDSigningClient,
        keychain: TokenKeychainStore<GoogleAccountInfo>
    ) {
        self.config = config
        self.client = client
        self.keychain = keychain
        if config.isConfigured {
            client.configure(clientID: config.clientID)
        }
    }

    func signIn(presenting: UIViewController) async throws -> GoogleAccountInfo {
        guard config.isConfigured else { throw GoogleAuthError.notConfigured }
        let info = try await client.signIn(presenting: presenting, scopes: scopes)
        try keychain.save(info)
        return info
    }

    func signOut() async {
        client.signOut()
        try? keychain.clear()
    }

    func currentAccount() -> GoogleAccountInfo? {
        (try? keychain.load()) ?? client.currentSnapshot()
    }

    func accessToken() async throws -> String {
        guard let cached = try keychain.load() else {
            throw GoogleAuthError.reauthenticationRequired
        }
        if cached.expiresAt.timeIntervalSinceNow > Self.refreshLeeway {
            return cached.accessToken
        }
        let refreshed = try await client.refresh()
        try keychain.save(refreshed)
        return refreshed.accessToken
    }
}
