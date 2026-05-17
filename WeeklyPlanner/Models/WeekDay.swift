import Foundation

/// One day cell in the week strip / hobonichi week page. Pure value type —
/// recomputed from `WeekMath` whenever the week changes. Never persisted.
struct WeekDay: Equatable, Hashable {
    /// 0...6, Monday-based (`weekStartsOnMonday` toggle in Settings can shift).
    let idx: Int
    /// Week offset relative to "today's week" (0 = current, -1 = last, +1 = next).
    let offset: Int
    let date: Date

    let weekdayShort: String
    let weekdayLong: String
    /// Single character ("M", "T", "W", …). Tuesday and Thursday both start
    /// with "T", which is intentional — matches the side-tab strip in the mock.
    let weekdayInitial: String

    let dayNumber: Int
    let monthShort: String
    let year: Int
}

/// Header metadata for a week. The range string is what shows up in the
/// top-bar date pill ("May 11 – 17" or "May 30 – Jun 5").
struct WeekMeta: Equatable, Hashable {
    let offset: Int
    /// ISO week number (1...53).
    let weekNumber: Int
    /// Display string, e.g., `"May 11 – 17"` for same-month weeks.
    let range: String
    /// `"May 2026"` style — used as the picker month caption.
    let monthFull: String
    /// True iff this is the current calendar week (offset == 0).
    let isCurrent: Bool
}
