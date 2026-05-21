import Foundation
import UserNotifications

/// Thin protocol seam over `UNUserNotificationCenter` so the schedulers can
/// be unit-tested without touching the system service.
@MainActor
protocol NotificationCentering: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func add(_ request: UNNotificationRequest) async throws
    func pendingRequests() async -> [UNNotificationRequest]
    func removePending(withIdentifiers identifiers: [String])
    func removeAllPending()
}

/// Production wrapper around `UNUserNotificationCenter.current()`. No logic;
/// every method delegates straight through. The whole point of this type is
/// that it can be swapped for `FakeNotificationCenter` in tests.
@MainActor
final class LiveNotificationCenter: NotificationCentering {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        center.setNotificationCategories(categories)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func removePending(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeAllPending() {
        center.removeAllPendingNotificationRequests()
    }
}
