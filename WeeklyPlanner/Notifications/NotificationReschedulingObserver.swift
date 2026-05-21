import Foundation
import os

/// Bridges existing store change notifications to scheduler updates. Listens
/// to `.eventStoreDidChange` and `.taskStoreDidChange` (already posted by
/// `SwiftDataEventStore` / `SwiftDataTaskStore` on every upsert/delete) and
/// calls the scheduler's `rescheduleAll` over a short forward window.
///
/// Bulk re-schedule is cheap because the schedulers clear by id-prefix
/// before re-adding — no leakage.
@MainActor
final class NotificationReschedulingObserver {
    private static let log = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "Notifications")

    private let eventScheduler: EventNotificationScheduler
    private let taskScheduler: TaskNotificationScheduler
    private nonisolated(unsafe) var observers: [NSObjectProtocol] = []

    init(eventScheduler: EventNotificationScheduler, taskScheduler: TaskNotificationScheduler) {
        self.eventScheduler = eventScheduler
        self.taskScheduler = taskScheduler
        attach()
    }

    deinit {
        let center = NotificationCenter.default
        for token in observers { center.removeObserver(token) }
    }

    /// Called once after a permission grant.
    func rescheduleNext30Days() async {
        let window = Date()...Date().addingTimeInterval(60 * 60 * 24 * 30)
        await eventScheduler.rescheduleAll(in: window)
        await taskScheduler.rescheduleAll(in: window)
    }

    private func attach() {
        let center = NotificationCenter.default
        let eventToken = center.addObserver(forName: .eventStoreDidChange, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in
                await self?.rescheduleNext30Days()
            }
        }
        let taskToken = center.addObserver(forName: .taskStoreDidChange, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in
                await self?.rescheduleNext30Days()
            }
        }
        observers = [eventToken, taskToken]
    }
}
