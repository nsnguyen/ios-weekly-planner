import Foundation
import UserNotifications
import os

/// Wraps the alert+sound+badge+timeSensitive opt-in flow. Callers either
/// observe the current `status()` to gate UI affordances, or fire `request()`
/// on first need.
@MainActor
final class NotificationAuthorization {
    static let log = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "Notifications")

    private let center: any NotificationCentering

    init(center: any NotificationCentering) {
        self.center = center
    }

    /// Returns the current OS-reported status. Cheap; safe to call every render.
    func status() async -> UNAuthorizationStatus {
        await center.authorizationStatus()
    }

    /// Requests `[.alert, .sound, .badge, .timeSensitive]`. Returns the user's
    /// answer translated to a `UNAuthorizationStatus`. Logs the outcome via
    /// `os.Logger` (use `log show --info`).
    func request() async -> UNAuthorizationStatus {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
            Self.log.info("Notification auth request granted=\(granted, privacy: .public)")
        } catch {
            Self.log.error("Notification auth request failed: \(String(describing: error), privacy: .public)")
        }
        return await center.authorizationStatus()
    }
}
