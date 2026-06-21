import Foundation

/// Errors surfaced by `GoogleAuthService`. UI-layer code maps these to user-
/// visible alerts; the `notConfigured` case fires when `Secrets.xcconfig`
/// hasn't been filled in (intentional graceful-degradation rather than a
/// crash so the rest of the app keeps running for non-Gmail features).
enum GoogleAuthError: Error, Equatable, Sendable {
    /// `Bundle.main`'s `GoogleClientID` key is missing or empty.
    case notConfigured
    /// User dismissed the OAuth sheet.
    case userCancelled
    /// Network error during sign-in or token refresh.
    case network(String)
    /// Token refresh failed because the user revoked from Google's side, or the
    /// refresh token itself is invalid. UI should flip `gmailConnected=false`.
    case reauthenticationRequired
    /// No `UIWindowScene` available to present the OAuth sheet from. Should
    /// never happen in a foreground app; defensive.
    case noPresenter
}
