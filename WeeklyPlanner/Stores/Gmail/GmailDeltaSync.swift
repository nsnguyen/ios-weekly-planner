import Foundation

/// Reads + writes the Gmail history-API cursor stored in
/// `UserSettings.gmailLastHistoryId`. Used by `InboxSyncEngine` to decide
/// between a delta sync (cursor present) and a full re-sync (cursor nil or
/// expired).
@MainActor
final class GmailDeltaSync {
    private let settingsStore: any SettingsStoring

    init(settingsStore: any SettingsStoring) {
        self.settingsStore = settingsStore
    }

    func currentCursor() -> String? {
        try? settingsStore.current().gmailLastHistoryId
    }

    func saveCursor(_ id: String) {
        try? settingsStore.update { $0.gmailLastHistoryId = id }
    }

    func clearCursor() {
        try? settingsStore.update { $0.gmailLastHistoryId = nil }
    }
}
