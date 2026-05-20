import Foundation

/// Reads the Google OAuth client ID at process startup. Sourced from the
/// `Secrets.xcconfig`-driven Info.plist key `GoogleClientID`; an empty or
/// missing value means the developer hasn't filled in `Secrets.xcconfig`
/// and `LiveGoogleAuthService.signIn(...)` will throw
/// `GoogleAuthError.notConfigured` rather than crash.
struct GoogleAuthConfig {
    let clientID: String

    /// Reads from `Bundle.main`'s Info.plist. Returns an empty `clientID` when
    /// the key is absent or blank.
    static func fromBundle(_ bundle: Bundle = .main) -> GoogleAuthConfig {
        let raw = bundle.object(forInfoDictionaryKey: "GoogleClientID") as? String
        return GoogleAuthConfig(clientID: raw?.trimmingCharacters(in: .whitespaces) ?? "")
    }

    var isConfigured: Bool { !clientID.isEmpty }
}
