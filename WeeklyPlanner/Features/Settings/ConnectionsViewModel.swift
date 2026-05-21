import Foundation
import Observation
import UIKit

/// Orchestrates the Gmail row's connect / disconnect side effects so the
/// SwiftUI `ConnectionsSection` stays declarative.
///
/// Flow on connect: optimistic flag flip → `auth.signIn(...)` → on success
/// persist `gmailConnected=true` + `gmailAccountEmail` and broadcast
/// `Notification.Name.gmailDidConnect` (Phase 18 listens to kick a one-shot
/// sync). On cancel: silently revert. On network/notConfigured: revert AND
/// surface a `ConnectionsAlert` the view binds to.
///
/// Flow on disconnect: `auth.signOut()` + clear Keychain + flip
/// `gmailConnected=false` + cascade-delete pending `InboxSuggestion` rows so
/// a re-connect doesn't resurrect stale suggestions from the prior account.
@MainActor
@Observable
final class ConnectionsViewModel {
    /// Mirror of `UserSettings.gmailConnected` for the toggle binding.
    private(set) var isGmailConnected: Bool = false
    /// Account email for the row's detail line; nil when disconnected.
    private(set) var gmailAccountEmail: String?
    /// Transient alert state; the view binds and clears via `dismissAlert()`.
    var alert: ConnectionsAlert?

    private let settingsStore: any SettingsStoring
    private let inboxStore: any InboxStoring
    private let auth: any GoogleAuthService

    init(
        settingsStore: any SettingsStoring,
        inboxStore: any InboxStoring,
        auth: any GoogleAuthService
    ) {
        self.settingsStore = settingsStore
        self.inboxStore = inboxStore
        self.auth = auth
        refreshFromSettings()
    }

    /// Re-reads `gmailConnected` / `gmailAccountEmail` from the store. Called
    /// at init and after every successful connect/disconnect.
    func refreshFromSettings() {
        guard let settings = try? settingsStore.current() else { return }
        isGmailConnected = settings.gmailConnected
        gmailAccountEmail = settings.gmailAccountEmail
    }

    func connectGmail(presenter: UIViewController) async {
        do {
            let account = try await auth.signIn(presenting: presenter)
            try settingsStore.update { s in
                s.gmailConnected = true
                s.gmailAccountEmail = account.email
            }
            refreshFromSettings()
            NotificationCenter.default.post(name: .gmailDidConnect, object: account.email)
        } catch GoogleAuthError.userCancelled {
            refreshFromSettings()
        } catch GoogleAuthError.notConfigured {
            refreshFromSettings()
            alert = .notConfigured
        } catch {
            refreshFromSettings()
            alert = .connectFailed
        }
    }

    func disconnectGmail() async {
        await auth.signOut()
        try? await inboxStore.clearPending()
        try? settingsStore.update { s in
            s.gmailConnected = false
            s.gmailAccountEmail = nil
        }
        refreshFromSettings()
    }

    func dismissAlert() { alert = nil }
}

/// Transient alert state surfaced from `ConnectionsViewModel`. Two cases for
/// v1.0; more get added as Phase 18 reauthentication-required surfaces here.
struct ConnectionsAlert: Equatable {
    let title: String
    let message: String

    static let connectFailed = ConnectionsAlert(
        title: "Couldn't connect Gmail",
        message: "Check your network and try again."
    )

    static let notConfigured = ConnectionsAlert(
        title: "Gmail isn't configured",
        message: "Add your Google OAuth client ID to Secrets.xcconfig and rebuild. See README."
    )
}

extension Notification.Name {
    /// Posted by `ConnectionsViewModel.connectGmail` on success. Phase 18's
    /// `InboxSyncEngine` listens and kicks a one-shot sync so the user sees
    /// suggestions appear within ~10s of toggling the row on.
    static let gmailDidConnect = Notification.Name("WeeklyPlanner.gmailDidConnect")
}
