import Foundation
import UserNotifications

/// Builds `UNNotificationContent` for time-based and location-based alerts.
///
/// All user-facing strings go through `String(localized:)` so Phase 21 can
/// translate them by simply filling the catalog. Titles longer than 64 chars
/// are truncated with an ellipsis (`"…"`) — keeps Lock Screen previews tidy.
enum NotificationContentBuilder {
    static let maxTitleLength = 64

    static func timeBased(title: String,
                          startsAt: Date,
                          location: String?,
                          minutesBefore: Int) -> UNMutableNotificationContent
    {
        let content = baseContent()
        content.title = truncate(title)
        content.subtitle = makeSubtitle(startsAt: startsAt, location: location)
        let formatString = String(localized: "In \(minutesBefore) minutes.",
                                  comment: "Time-based reminder body. Argument is minutes-before-start.")
        content.body = formatString
        content.categoryIdentifier = NotificationCategoryIDs.event
        return content
    }

    static func locationBased(title: String, locationName: String) -> UNMutableNotificationContent {
        let content = baseContent()
        content.title = truncate(title)
        let formatString = String(localized: "You've arrived at \(locationName).",
                                  comment: "Location-based reminder body. Argument is the place name.")
        content.body = formatString
        content.subtitle = locationName
        content.categoryIdentifier = NotificationCategoryIDs.event
        return content
    }

    /// Mirror of `timeBased`/`locationBased` for tasks. Uses the task category
    /// so the action set includes "Mark Done".
    static func taskTimeBased(title: String, dueAt: Date) -> UNMutableNotificationContent {
        let content = baseContent()
        content.title = truncate(title)
        content.subtitle = makeSubtitle(startsAt: dueAt, location: nil)
        content.body = String(localized: "Task reminder.", comment: "Task time-based body.")
        content.categoryIdentifier = NotificationCategoryIDs.task
        return content
    }

    static func taskLocationBased(title: String, locationName: String) -> UNMutableNotificationContent {
        let content = baseContent()
        content.title = truncate(title)
        content.subtitle = locationName
        content.body = String(localized: "You've arrived at \(locationName).",
                              comment: "Task location-based body.")
        content.categoryIdentifier = NotificationCategoryIDs.task
        return content
    }

    private static func baseContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        return content
    }

    private static func truncate(_ title: String) -> String {
        guard title.count > maxTitleLength else { return title }
        let prefix = title.prefix(maxTitleLength - 1)
        return "\(prefix)…"
    }

    private static func makeSubtitle(startsAt: Date, location: String?) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let time = formatter.string(from: startsAt)
        if let location, !location.isEmpty {
            return "\(time) · \(location)"
        }
        return time
    }
}
