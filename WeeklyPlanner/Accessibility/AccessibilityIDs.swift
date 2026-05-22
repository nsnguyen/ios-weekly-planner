import Foundation

/// Stable accessibility identifiers used by XCUITest to locate UI
/// elements. Keep them stable across releases — UI test scripts on CI
/// depend on these literals.
enum AccessibilityIDs {
    // Day page
    static func daypageEventRow(_ id: UUID) -> String { "daypage.event.row.\(id)" }
    static func daypageTodoRow(_ id: UUID) -> String { "daypage.todo.row.\(id)" }
    static let daypageAIButton = "daypage.ai.button"
    static let daypageTodayPill = "daypage.today.pill"
    static let daypageStickyNote = "daypage.sticky.note"

    // Side tabs
    static func sideTab(_ dayIdx: Int) -> String { "daypage.sidetab.\(dayIdx)" }

    // Week picker
    static func weekpickerWeekRow(_ offset: Int) -> String { "weekpicker.weekrow.\(offset)" }

    // Settings
    static func settingsThemeCard(_ key: String) -> String { "settings.theme.card.\(key)" }
    static func settingsFontCard(_ key: String) -> String { "settings.font.card.\(key)" }
    static func settingsSizeSegment(_ key: String) -> String { "settings.size.segment.\(key)" }

    // AI search overlay
    static let aiSearchInput = "aisearch.input"
    static let aiSearchClose = "aisearch.close"

    // Event sheet
    static let eventSheetDelete = "eventsheet.delete"

    // Tab bar
    static func tabBarTab(_ tab: String) -> String { "tabbar.tab.\(tab)" }
}
