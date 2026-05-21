import Foundation
import SwiftData

/// The single settings record. Exactly one row exists per install; load via
/// `SettingsStore.current()` which lazy-creates the row on first access.
///
/// Most properties are stored as String / Int / Bool so SwiftData can index
/// and predicate-filter them. Enum accessors at the bottom expose typed
/// views for ergonomic call-sites.
@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID

    // Visual
    var themeKey: String
    var fontKey: String
    var sizeKey: String

    /// Week math
    var weekStartsOnMonday: Bool

    /// Reminders
    /// `nil | 5 | 15 | 30 | 60`. Default `15`.
    var defaultReminderMinutes: Int?

    /// AI
    var appleIntelligenceEnabled: Bool

    // Integrations
    var gmailConnected: Bool
    var gmailAccountEmail: String?
    var googleCalendarConnected: Bool
    var appleMailConnected: Bool
    /// Gmail history API cursor. Set by `GmailDeltaSync` after each
    /// successful sync; `nil` means a full re-sync is required (first
    /// run, or after `history?` returned 404 because the cursor aged out).
    var gmailLastHistoryId: String?

    // Style
    var styleRaw: String
    var modernViewRaw: String
    var paperViewRaw: String
    var accentHex: String

    /// Active tab on the bottom paper tab bar (Phase 15). Stored as the
    /// `Tab.rawValue` String so SwiftData can index/predicate-filter it.
    var lastTabRaw: String

    var updatedAt: Date

    init(id: UUID = UUID(),
         themeKey: String = PaperThemeKey.cream.rawValue,
         fontKey: String = PaperFont.caveat.rawValue,
         sizeKey: String = PaperSize.m.rawValue,
         weekStartsOnMonday: Bool = true,
         defaultReminderMinutes: Int? = 15,
         appleIntelligenceEnabled: Bool = true,
         gmailConnected: Bool = false,
         gmailAccountEmail: String? = nil,
         googleCalendarConnected: Bool = false,
         appleMailConnected: Bool = true,
         gmailLastHistoryId: String? = nil,
         style: AppStyle = .paper,
         modernView: ModernView = .day,
         paperView: PaperView = .day,
         accentHex: String = "#0A84FF",
         lastTabRaw: String = "calendar",
         updatedAt: Date = .init())
    {
        self.id = id
        self.themeKey = themeKey
        self.fontKey = fontKey
        self.sizeKey = sizeKey
        self.weekStartsOnMonday = weekStartsOnMonday
        self.defaultReminderMinutes = defaultReminderMinutes
        self.appleIntelligenceEnabled = appleIntelligenceEnabled
        self.gmailConnected = gmailConnected
        self.gmailAccountEmail = gmailAccountEmail
        self.googleCalendarConnected = googleCalendarConnected
        self.appleMailConnected = appleMailConnected
        self.gmailLastHistoryId = gmailLastHistoryId
        styleRaw = style.rawValue
        modernViewRaw = modernView.rawValue
        paperViewRaw = paperView.rawValue
        self.accentHex = accentHex
        self.lastTabRaw = lastTabRaw
        self.updatedAt = updatedAt
    }
}

extension UserSettings {
    var paperTheme: PaperThemeKey {
        get { PaperThemeKey(rawValue: themeKey) ?? .cream }
        set { themeKey = newValue.rawValue }
    }

    var paperFont: PaperFont {
        get { PaperFont(rawValue: fontKey) ?? .caveat }
        set { fontKey = newValue.rawValue }
    }

    var paperSize: PaperSize {
        get { PaperSize(rawValue: sizeKey) ?? .m }
        set { sizeKey = newValue.rawValue }
    }

    var style: AppStyle {
        get { AppStyle(rawValue: styleRaw) ?? .paper }
        set { styleRaw = newValue.rawValue }
    }

    var modernView: ModernView {
        get { ModernView(rawValue: modernViewRaw) ?? .day }
        set { modernViewRaw = newValue.rawValue }
    }

    var paperView: PaperView {
        get { PaperView(rawValue: paperViewRaw) ?? .day }
        set { paperViewRaw = newValue.rawValue }
    }
}
