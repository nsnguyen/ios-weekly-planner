import Foundation
import Observation
import UIKit

/// Minimal protocol so `ConnectionsViewModel` can call `purge()` on the sync
/// engine without a hard dependency on the concrete `GCalSyncEngine`. Lets
/// tests inject a spy without spinning up a real event store.
@MainActor
protocol GCalPurging: AnyObject {
    func purge() async
}

/// Orchestrates the Gmail and Google Calendar rows' connect / disconnect
/// side effects so the SwiftUI `ConnectionsSection` stays declarative.
///
/// Flow on connect (Gmail): optimistic flag flip → `auth.signIn(...)` → on
/// success persist `gmailConnected=true` + `gmailAccountEmail` and broadcast
/// `Notification.Name.gmailDidConnect` (Phase 18 listens to kick a one-shot
/// sync). On cancel: silently revert. On network/notConfigured: revert AND
/// surface a `ConnectionsAlert` the view binds to.
///
/// Flow on disconnect (Gmail): `auth.signOut()` + clear Keychain + flip
/// `gmailConnected=false` + cascade-delete pending `InboxSuggestion` rows so
/// a re-connect doesn't resurrect stale suggestions from the prior account.
///
/// Flow on connect (Google Calendar): `auth.signIn(...)` (idempotent — returns
/// the existing account if already signed in; `calendar.events` scope is in
/// the request), persist `googleCalendarConnected=true` + email, post
/// `.googleCalendarDidConnect` to trigger a one-shot sync (Task 10).
///
/// Flow on disconnect (Google Calendar): `gcalPurger.purge()` (deletes all
/// `.googleCalendar` events and clears the `gcalSyncToken`), then clears
/// `googleCalendarConnected` / `googleCalendarAccountEmail` in settings.
/// Does NOT call `auth.signOut()` — Gmail and Calendar share the same Google
/// OAuth token; revoking it here would break a connected Gmail.
@MainActor
@Observable
final class ConnectionsViewModel {
    /// Mirror of `UserSettings.gmailConnected` for the toggle binding.
    private(set) var isGmailConnected: Bool = false
    /// Account email for the Gmail row's detail line; nil when disconnected.
    private(set) var gmailAccountEmail: String?

    /// Mirror of `UserSettings.googleCalendarConnected` for the toggle binding.
    private(set) var isGoogleCalendarConnected: Bool = false
    /// Account email for the Google Calendar row's detail line; nil when disconnected.
    private(set) var googleCalendarAccountEmail: String?

    /// Transient alert state; the view binds and clears via `dismissAlert()`.
    var alert: ConnectionsAlert?

    private let settingsStore: any SettingsStoring
    private let inboxStore: any InboxStoring
    private let auth: any GoogleAuthService
    private let gcalPurger: (any GCalPurging)?

    init(
        settingsStore: any SettingsStoring,
        inboxStore: any InboxStoring,
        auth: any GoogleAuthService,
        gcalSyncEngine: (any GCalPurging)? = nil
    ) {
        self.settingsStore = settingsStore
        self.inboxStore = inboxStore
        self.auth = auth
        self.gcalPurger = gcalSyncEngine
        refreshFromSettings()
    }

    /// Re-reads persisted state from the store. Called at init and after
    /// every successful connect/disconnect.
    func refreshFromSettings() {
        guard let settings = try? settingsStore.current() else { return }
        isGmailConnected = settings.gmailConnected
        gmailAccountEmail = settings.gmailAccountEmail
        isGoogleCalendarConnected = settings.googleCalendarConnected
        googleCalendarAccountEmail = settings.googleCalendarAccountEmail
    }

    // MARK: - Gmail

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

    // MARK: - Google Calendar

    func connectGoogleCalendar(presenter: UIViewController) async {
        do {
            let account = try await auth.signIn(presenting: presenter)
            try settingsStore.update { s in
                s.googleCalendarConnected = true
                s.googleCalendarAccountEmail = account.email
            }
            refreshFromSettings()
            NotificationCenter.default.post(name: .googleCalendarDidConnect, object: account.email)
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

    /// Disconnects Google Calendar WITHOUT revoking the shared OAuth token.
    /// Gmail uses the same token — calling `auth.signOut()` here would break
    /// an active Gmail connection. Instead, we purge local data and clear the
    /// connection flags only.
    func disconnectGoogleCalendar() async {
        await gcalPurger?.purge()
        try? settingsStore.update { s in
            s.googleCalendarConnected = false
            s.googleCalendarAccountEmail = nil
        }
        refreshFromSettings()
    }

    func dismissAlert() { alert = nil }
}

// MARK: - GCalSyncEngine conformance

extension GCalSyncEngine: GCalPurging {}

// MARK: - ConnectionsAlert

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

// MARK: - Notification.Name

extension Notification.Name {
    /// Posted by `ConnectionsViewModel.connectGmail` on success. Phase 18's
    /// `InboxSyncEngine` listens and kicks a one-shot sync so the user sees
    /// suggestions appear within ~10s of toggling the row on.
    static let gmailDidConnect = Notification.Name("WeeklyPlanner.gmailDidConnect")

    /// Posted by `ConnectionsViewModel.connectGoogleCalendar` on success.
    /// Task 10 wires a listener that kicks a one-shot GCal sync.
    static let googleCalendarDidConnect = Notification.Name("WeeklyPlanner.GoogleCalendar.didConnect")
}
