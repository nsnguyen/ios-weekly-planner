import Foundation

/// The minimal account snapshot the app keeps in Keychain after a successful
/// Google OAuth sign-in. Refreshed in place by `GoogleAuthService.accessToken()`
/// when `expiresAt` is within five minutes of `now`.
struct GoogleAccountInfo: Codable, Equatable, Hashable, Sendable {
    let email: String
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}
