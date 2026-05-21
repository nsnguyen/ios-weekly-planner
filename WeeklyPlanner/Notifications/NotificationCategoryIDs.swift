import UserNotifications

/// Identifiers for the actionable categories registered once at app launch.
///
/// Two category ids — one for events, one for tasks — so the action set
/// shown on long-press / swipe differs per content type. Action ids land in
/// `response.actionIdentifier` inside the `UNUserNotificationCenterDelegate`
/// callback.
enum NotificationCategoryIDs {
    static let event = "com.weeklyplanner.notification.event"
    static let task  = "com.weeklyplanner.notification.task"

    enum Action {
        static let viewEvent  = "com.weeklyplanner.action.viewEvent"
        static let snooze10   = "com.weeklyplanner.action.snooze10"
        static let viewTask   = "com.weeklyplanner.action.viewTask"
        static let markDone   = "com.weeklyplanner.action.markDone"
    }

    /// The full category set to register via `NotificationCentering.setNotificationCategories(_:)`
    /// during app launch. Phase 21 will localize the user-visible action titles.
    static func all() -> Set<UNNotificationCategory> {
        let view = UNNotificationAction(
            identifier: Action.viewEvent,
            title: String(localized: "View"),
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: Action.snooze10,
            title: String(localized: "Snooze 10 min"),
            options: []
        )
        let eventCategory = UNNotificationCategory(
            identifier: event,
            actions: [view, snooze],
            intentIdentifiers: [],
            options: []
        )

        let viewTask = UNNotificationAction(
            identifier: Action.viewTask,
            title: String(localized: "View"),
            options: [.foreground]
        )
        let markDone = UNNotificationAction(
            identifier: Action.markDone,
            title: String(localized: "Mark Done"),
            options: [.destructive]
        )
        let taskCategory = UNNotificationCategory(
            identifier: task,
            actions: [viewTask, markDone],
            intentIdentifiers: [],
            options: []
        )

        return [eventCategory, taskCategory]
    }
}
