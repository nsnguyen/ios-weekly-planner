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

    // Top bar — Day/Week toggle segments + week chevrons
    static func dayWeekSegment(_ view: String) -> String { "topbar.dayweek.\(view)" }
    static let weekChevronPrev = "topbar.week.chevron.prev"
    static let weekChevronNext = "topbar.week.chevron.next"
    /// The date-range pill that opens the week picker. Its a11y *value* is the
    /// visible range string (e.g. "May 25 – 31"), used to assert week changes.
    static let dateRangePill = "topbar.daterange.pill"

    // Week page
    static func weekpageDayRow(_ dayIdx: Int) -> String { "weekpage.day.row.\(dayIdx)" }
    static func weekpageTodoRow(_ id: UUID) -> String { "weekpage.todo.row.\(id)" }

    // Week picker
    static func weekpickerWeekRow(_ offset: Int) -> String { "weekpicker.weekrow.\(offset)" }

    // Week picker — month/year navigation bar (Phase 31)
    static let weekpickerMonthPrev = "weekpicker.nav.month.prev"
    static let weekpickerMonthNext = "weekpicker.nav.month.next"
    static let weekpickerYearPrev = "weekpicker.nav.year.prev"
    static let weekpickerYearNext = "weekpicker.nav.year.next"
    static let weekpickerNavTitle = "weekpicker.nav.title"

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
