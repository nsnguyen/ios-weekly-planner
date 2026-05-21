import BackgroundTasks
import Foundation

/// Wraps `BGTaskScheduler` for the Gmail refresh task. Registered once at
/// app startup; submitted at the end of every foreground sync with a
/// 1-hour earliest-begin window.
@MainActor
final class BackgroundRefreshScheduler {
    static let taskIdentifier = "com.weeklyplanner.WeeklyPlanner.gmailRefresh"
    private let engine: InboxSyncEngine

    init(engine: InboxSyncEngine) {
        self.engine = engine
    }

    /// Called once from `WeeklyPlannerApp.init` before `body` is built.
    func registerHandler() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handle(task: task as! BGAppRefreshTask)
        }
    }

    /// Submitted after every foreground sync to keep the queue full.
    func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // 1h
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(task: BGAppRefreshTask) {
        // Always re-schedule so the queue stays primed.
        scheduleNext()
        let engine = self.engine
        let work = Task { @MainActor in
            do {
                _ = try await engine.sync(now: Date())
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        task.expirationHandler = { work.cancel() }
    }
}
