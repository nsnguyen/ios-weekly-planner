import Foundation

/// Read/write bridge between `PaperSettingsView` and `SettingsStoring`.
/// Mirrors `UserSettings` properties as typed values, with setters that
/// persist through `store.update { ... }`. Constructed in
/// `PaperSettingsView.task` so a fresh navigation always reads the latest
/// row (rather than caching across mount cycles).
@MainActor
@Observable
final class SettingsViewModel {
    private let store: any SettingsStoring

    var themeKey: PaperThemeKey
    var fontKey: PaperFont
    var sizeKey: PaperSize
    var weekStartsOnMonday: Bool
    var defaultReminderMinutes: Int?
    var appleIntelligenceEnabled: Bool
    var aiStickyNotesEnabled: Bool

    init(store: any SettingsStoring) {
        self.store = store
        let settings = (try? store.current()) ?? UserSettings()
        themeKey = settings.paperTheme
        fontKey = settings.paperFont
        sizeKey = settings.paperSize
        weekStartsOnMonday = settings.weekStartsOnMonday
        defaultReminderMinutes = settings.defaultReminderMinutes
        appleIntelligenceEnabled = settings.appleIntelligenceEnabled
        aiStickyNotesEnabled = settings.aiStickyNotesEnabled
    }

    func setTheme(_ theme: PaperThemeKey) {
        themeKey = theme
        try? store.update { $0.paperTheme = theme }
    }

    func setFont(_ font: PaperFont) {
        fontKey = font
        try? store.update { $0.paperFont = font }
    }

    func setSize(_ size: PaperSize) {
        sizeKey = size
        try? store.update { $0.paperSize = size }
    }

    func setWeekStartsOnMonday(_ value: Bool) {
        weekStartsOnMonday = value
        try? store.update { $0.weekStartsOnMonday = value }
    }

    func setDefaultReminderMinutes(_ minutes: Int?) {
        defaultReminderMinutes = minutes
        try? store.update { $0.defaultReminderMinutes = minutes }
    }

    func setAppleIntelligenceEnabled(_ value: Bool) {
        appleIntelligenceEnabled = value
        try? store.update { $0.appleIntelligenceEnabled = value }
    }

    func setAIStickyNotesEnabled(_ value: Bool) {
        aiStickyNotesEnabled = value
        try? store.update { $0.aiStickyNotesEnabled = value }
    }
}
