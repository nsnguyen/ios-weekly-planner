import Foundation

/// Reads + writes the Google Calendar sync cursor stored in
/// `UserSettings.gcalSyncToken`. Used by the sync engine to decide
/// between a delta sync (cursor present) and a full re-sync (cursor nil or
/// expired).
@MainActor
final class GCalDeltaSync {
    private let settingsStore: any SettingsStoring

    init(settingsStore: any SettingsStoring) {
        self.settingsStore = settingsStore
    }

    func currentToken() -> String? {
        try? settingsStore.current().gcalSyncToken
    }

    func save(_ token: String?) {
        try? settingsStore.update { $0.gcalSyncToken = token }
    }
}
