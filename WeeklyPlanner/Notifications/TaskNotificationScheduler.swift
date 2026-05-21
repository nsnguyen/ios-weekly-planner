import Foundation
import UserNotifications
import os

/// Mirrors `EventNotificationScheduler` for `TaskItem` — `reminderTime`
/// becomes a `UNCalendarNotificationTrigger`, `locationReminder` becomes a
/// region monitored by `LocationRegistering`.
///
/// Identifier shapes:
///   - `task-{uuid}-time`   — calendar trigger
///   - `task-{uuid}-arrive` — location trigger (registered through registrar)
@MainActor
final class TaskNotificationScheduler {
    private static let log = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "Notifications")

    private let center: any NotificationCentering
    private let locationRegistrar: any LocationRegistering
    private let taskStore: (any TaskStoring)?

    init(center: any NotificationCentering,
         locationRegistrar: any LocationRegistering,
         taskStore: (any TaskStoring)? = nil)
    {
        self.center = center
        self.locationRegistrar = locationRegistrar
        self.taskStore = taskStore
    }

    func schedule(task: TaskItem) async throws {
        let prefix = "task-\(task.id.uuidString)-"
        let pending = await center.pendingRequests()
        let toRemove = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !toRemove.isEmpty {
            center.removePending(withIdentifiers: toRemove)
        }
        locationRegistrar.unregister(eventID: task.id)

        if let when = task.reminderTime, when > Date() {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: when)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let content = NotificationContentBuilder.taskTimeBased(title: task.title, dueAt: when)
            content.userInfo = ["task.id": task.id.uuidString]
            let id = "task-\(task.id.uuidString)-time"
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            Self.log.info("Scheduled task-time \(id, privacy: .public)")
        }

        if let region = task.locationReminder {
            let title = task.title
            _ = locationRegistrar.register(
                eventID: task.id,
                reminder: region,
                content: {
                    let content = NotificationContentBuilder.taskLocationBased(title: title, locationName: region.name)
                    content.userInfo = ["task.id": task.id.uuidString]
                    return content
                },
                proximityInDays: max(0, Calendar.current.dateComponents([.day], from: Date(), to: task.due).day ?? 0)
            )
            Self.log.info("Registered task arrival region \(task.id, privacy: .public)")
        }
    }

    func cancel(taskID: UUID) async {
        let prefix = "task-\(taskID.uuidString)-"
        let pending = await center.pendingRequests()
        let toRemove = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        if !toRemove.isEmpty {
            center.removePending(withIdentifiers: toRemove)
        }
        locationRegistrar.unregister(eventID: taskID)
    }

    func rescheduleAll(in window: ClosedRange<Date>) async {
        guard let store = taskStore else {
            Self.log.error("rescheduleAll called without TaskStoring")
            return
        }
        // Tasks are weekly-bucketed; iterate the same week offsets as events.
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let startOffset = cal.dateComponents([.weekOfYear], from: now, to: window.lowerBound).weekOfYear ?? 0
        let endOffset = cal.dateComponents([.weekOfYear], from: now, to: window.upperBound).weekOfYear ?? 0
        var tasks: [TaskItem] = []
        for offset in startOffset...endOffset {
            do { tasks.append(contentsOf: try await store.tasks(forWeekOffset: offset, today: now)) }
            catch { Self.log.error("rescheduleAll task fetch failed: \(String(describing: error), privacy: .public)") }
        }
        for task in tasks where task.done == false && window.contains(task.due) {
            do { try await schedule(task: task) }
            catch { Self.log.error("rescheduleAll task schedule failed: \(String(describing: error), privacy: .public)") }
        }
    }
}
