import Foundation
import UserNotifications

@MainActor
protocol LocationRegistering: AnyObject {
    @discardableResult
    func register(eventID: UUID,
                  reminder: LocationReminder,
                  content: @escaping () -> UNMutableNotificationContent,
                  proximityInDays: Int) -> String?

    func unregister(eventID: UUID)
}
