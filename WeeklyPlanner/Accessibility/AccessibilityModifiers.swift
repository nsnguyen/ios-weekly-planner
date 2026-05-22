import SwiftUI

/// String formatters for VoiceOver labels on composite surfaces. Pure
/// functions kept separate from the view modifiers so tests can assert
/// formatting without hosting SwiftUI.
enum AccessibilityFormatters {

    // MARK: - Event

    static func eventLabel(_ event: Event) -> String {
        let category = CategoryPalette.displayName(event.category)
        let timeRange = formatTimeRange(start: event.start, end: event.end)
        let location: String
        if let loc = event.location, !loc.isEmpty {
            location = loc
        } else {
            location = "no location"
        }
        let source = event.source == .gmail ? "from Gmail" : "added by you"
        return "\(event.title), \(category), \(timeRange), \(location), \(source)"
    }

    // MARK: - Task

    static func taskLabel(_ task: TaskItem) -> String {
        let state = task.done ? "completed" : "not completed"
        return "\(task.title), \(state)"
    }

    // MARK: - Navigation

    /// Side tab on the day page — "{Weekday}, day {N} of 7".
    static func sideTabLabel(weekdayFull: String, dayN: Int) -> String {
        "\(weekdayFull), day \(dayN) of 7"
    }

    /// Week-picker row — "Week of {range}, week {n}".
    static func weekRowLabel(range: String, weekNumber: Int) -> String {
        "Week of \(range), week \(weekNumber)"
    }

    // MARK: - Private helpers

    private static func formatTimeRange(start: Date, end: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE h:mma"
        let startStr = fmt.string(from: start)
        fmt.dateFormat = "h:mma"
        let endStr = fmt.string(from: end)
        return "\(startStr) to \(endStr)"
    }
}

// MARK: - View modifiers

extension View {

    /// Combine all child elements of an event row into one VoiceOver
    /// element with a descriptive label and a tap hint.
    func accessibleEvent(_ event: Event) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityFormatters.eventLabel(event))
            .accessibilityHint("Double tap to open details.")
            .accessibilityAddTraits(.isButton)
    }

    /// Combine task-row elements; tap toggles done state.
    func accessibleTask(_ task: TaskItem, onToggle: @escaping () -> Void) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityFormatters.taskLabel(task))
            .accessibilityHint("Double tap to toggle complete.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default) { onToggle() }
    }

    /// Side tab on the day page — announces day name and position.
    func accessibleSideTab(weekdayFull: String, dayN: Int) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityFormatters.sideTabLabel(weekdayFull: weekdayFull, dayN: dayN))
            .accessibilityHint("Double tap to flip to this day.")
            .accessibilityAddTraits(.isButton)
    }

    /// "Return to today" pill.
    func accessibleTodayPill() -> some View {
        self
            .accessibilityLabel("Return to today")
            .accessibilityAddTraits(.isButton)
    }

    /// Apple Intelligence search button.
    func accessibleAIButton() -> some View {
        self
            .accessibilityLabel("Apple Intelligence search")
            .accessibilityHint("Double tap to ask about your week.")
            .accessibilityAddTraits(.isButton)
    }

    /// Week-picker row — announces date range and week number.
    func accessibleWeekRow(range: String, weekNumber: Int) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityFormatters.weekRowLabel(range: range, weekNumber: weekNumber))
            .accessibilityHint("Double tap to jump to this week.")
            .accessibilityAddTraits(.isButton)
    }
}
