import UIKit
import UserNotifications
import os

/// `UIApplicationDelegate` + `UNUserNotificationCenterDelegate` adapter.
/// Responsibilities:
///   1. Register the actionable categories at launch.
///   2. Become the foreground-presentation delegate so notifications show as
///      banners even when the app is in front.
///   3. Translate tap / action / cold-launch payloads into `DeepLinkRouter`
///      requests + task-store side effects.
///
/// The delegate stays SwiftData-free in `application(_:didFinishLaunchingWithOptions:)`
/// — region-entry cold-launches must finish quickly to avoid OS termination.
@MainActor
final class NotificationsAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let log = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "Notifications")

    /// Set by `WeeklyPlannerApp.init` after construction. Optionality keeps the
    /// delegate cheap to instantiate.
    var router: DeepLinkRouter?
    var taskStore: (any TaskStoring)?
    var center: (any NotificationCentering)?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().setNotificationCategories(NotificationCategoryIDs.all())
        return true
    }

    // Show banners in foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler([.banner, .list, .sound])
    }

    // Tap / action handling.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void)
    {
        let userInfo = response.notification.request.content.userInfo
        let action = response.actionIdentifier
        let request = response.notification.request

        switch action {
        case NotificationCategoryIDs.Action.viewEvent,
             UNNotificationDefaultActionIdentifier:
            if let id = uuid(forKey: "event.id", in: userInfo) {
                router?.request(.event(id))
            } else if let id = uuid(forKey: "task.id", in: userInfo) {
                router?.request(.task(id))
            }
        case NotificationCategoryIDs.Action.viewTask:
            if let id = uuid(forKey: "task.id", in: userInfo) {
                router?.request(.task(id))
            }
        case NotificationCategoryIDs.Action.snooze10:
            Task { @MainActor [weak self] in
                await self?.snooze(request: request, by: 10 * 60)
            }
        case NotificationCategoryIDs.Action.markDone:
            if let id = uuid(forKey: "task.id", in: userInfo) {
                Task { @MainActor [weak self] in
                    try? await self?.taskStore?.toggle(id: id)
                    self?.center?.removePending(withIdentifiers: [request.identifier])
                }
            }
        default:
            break
        }

        completionHandler()
    }

    // MARK: - Private

    private func uuid(forKey key: String, in info: [AnyHashable: Any]) -> UUID? {
        guard let raw = info[key] as? String else { return nil }
        return UUID(uuidString: raw)
    }

    private func snooze(request: UNNotificationRequest, by seconds: TimeInterval) async {
        guard let center else { return }
        let newID = "\(request.identifier)-snooze-\(Int(Date().timeIntervalSince1970))"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let newRequest = UNNotificationRequest(identifier: newID,
                                                content: request.content,
                                                trigger: trigger)
        do {
            try await center.add(newRequest)
            Self.log.info("Snoozed notification \(request.identifier, privacy: .public) by \(seconds, privacy: .public)s")
        } catch {
            Self.log.error("Snooze re-add failed: \(String(describing: error), privacy: .public)")
        }
    }
}
