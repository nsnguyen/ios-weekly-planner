import Foundation
import GoogleSignIn
import UIKit

/// Thin adapter over `GIDSignIn.sharedInstance`. The protocol returns our own
/// `GoogleAccountInfo` (NOT `GIDGoogleUser`) so the test fake doesn't need to
/// construct SDK types. The real impl is the only place where SDK types are
/// touched in the auth layer.
@MainActor
protocol GIDSigningClient {
    /// Configures the SDK with the given client ID. Called once at app
    /// start-up; idempotent.
    func configure(clientID: String)

    /// Presents the OAuth sheet and returns the resulting account snapshot.
    func signIn(presenting: UIViewController, scopes: [String]) async throws -> GoogleAccountInfo

    /// Refreshes the access token using the cached refresh token.
    func refresh() async throws -> GoogleAccountInfo

    /// Hands a URL to the SDK (called from `WeeklyPlannerApp.onOpenURL`).
    func handle(url: URL) -> Bool

    /// Revokes server-side and clears the SDK's local cache.
    func signOut()

    /// Returns the SDK's currently-signed-in user as a snapshot, or `nil`.
    func currentSnapshot() -> GoogleAccountInfo?
}

@MainActor
final class RealGIDSigningClient: GIDSigningClient {
    func configure(clientID: String) {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

    func signIn(presenting: UIViewController, scopes: [String]) async throws -> GoogleAccountInfo {
        // kGIDSignInErrorCodeCanceled = -5; compared numerically because the
        // NS_ERROR_ENUM Swift type alias is not reliably importable by name.
        let canceledCode = -5
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: presenting,
                hint: nil,
                additionalScopes: scopes
            ) { result, error in
                // SDK callbacks are dispatched on the main queue, so it is
                // safe to read GIDGoogleUser properties here.
                if let error = error as NSError? {
                    if error.domain == kGIDSignInErrorDomain && error.code == canceledCode {
                        continuation.resume(throwing: GoogleAuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: GoogleAuthError.network(error.localizedDescription))
                    }
                    return
                }
                guard let user = result?.user else {
                    continuation.resume(throwing: GoogleAuthError.network("Sign-in result missing user"))
                    return
                }
                // Extract all Sendable values (String, Date) before leaving
                // the callback — avoids passing a non-Sendable GIDGoogleUser
                // across isolation boundaries.
                guard let email = user.profile?.email else {
                    continuation.resume(
                        throwing: GoogleAuthError.network("Missing email on Google profile")
                    )
                    return
                }
                let info = GoogleAccountInfo(
                    email: email,
                    accessToken: user.accessToken.tokenString,
                    refreshToken: user.refreshToken.tokenString,
                    expiresAt: user.accessToken.expirationDate ?? Date(timeIntervalSinceNow: 3000)
                )
                continuation.resume(returning: info)
            }
        }
    }

    func refresh() async throws -> GoogleAccountInfo {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw GoogleAuthError.reauthenticationRequired
        }
        return try await withCheckedThrowingContinuation { continuation in
            user.refreshTokensIfNeeded { updatedUser, error in
                // SDK callbacks are dispatched on the main queue.
                if error != nil {
                    continuation.resume(throwing: GoogleAuthError.reauthenticationRequired)
                    return
                }
                guard let updatedUser else {
                    continuation.resume(throwing: GoogleAuthError.reauthenticationRequired)
                    return
                }
                guard let email = updatedUser.profile?.email else {
                    continuation.resume(
                        throwing: GoogleAuthError.network("Missing email on Google profile")
                    )
                    return
                }
                let info = GoogleAccountInfo(
                    email: email,
                    accessToken: updatedUser.accessToken.tokenString,
                    refreshToken: updatedUser.refreshToken.tokenString,
                    expiresAt: updatedUser.accessToken.expirationDate ?? Date(timeIntervalSinceNow: 3000)
                )
                continuation.resume(returning: info)
            }
        }
    }

    func handle(url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    func currentSnapshot() -> GoogleAccountInfo? {
        guard let user = GIDSignIn.sharedInstance.currentUser else { return nil }
        return try? snapshot(from: user)
    }

    private func snapshot(from user: GIDGoogleUser) throws -> GoogleAccountInfo {
        guard let email = user.profile?.email else {
            throw GoogleAuthError.network("Missing email on Google profile")
        }
        return GoogleAccountInfo(
            email: email,
            accessToken: user.accessToken.tokenString,
            refreshToken: user.refreshToken.tokenString,
            expiresAt: user.accessToken.expirationDate ?? Date(timeIntervalSinceNow: 3000)
        )
    }
}
