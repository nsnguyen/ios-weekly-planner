import BackgroundTasks
import Foundation

/// Wraps `BGTaskScheduler` for the Gmail refresh task. Registered once at
/// app startup; submitted at the end of every foreground sync with a
/// 1-hour earliest-begin window.
///
/// Also hosts an optional Google Calendar background refresh slot
/// (`gcalTaskIdentifier`). Wire it by calling `registerGCalHandler(sync:)`
/// at app startup with a closure that runs `GCalSyncEngine.sync()`.
@MainActor
final class BackgroundRefreshScheduler {
    static let taskIdentifier = "com.weeklyplanner.WeeklyPlanner.gmailRefresh"
    static let gcalTaskIdentifier = "com.weeklyplanner.WeeklyPlanner.gcalRefresh"

    private let engine: InboxSyncEngine
    private var gcalSyncAction: (() async -> Void)?

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

    /// Called once from `WeeklyPlannerApp.init` to register the Google
    /// Calendar background refresh slot. `sync` is a closure that calls
    /// `GCalSyncEngine.sync()` — captured by the caller to avoid a direct
    /// dependency on `GCalSyncEngine` here.
    func registerGCalHandler(sync: @escaping () async -> Void) {
        gcalSyncAction = sync
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.gcalTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleGCal(task: task as! BGAppRefreshTask)
        }
    }

    /// Submitted after every foreground sync to keep the queue full.
    func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // 1h
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Submitted after every foreground GCal sync to keep the queue full.
    func scheduleNextGCal() {
        let request = BGAppRefreshTaskRequest(identifier: Self.gcalTaskIdentifier)
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

    private func handleGCal(task: BGAppRefreshTask) {
        // Always re-schedule so the queue stays primed.
        scheduleNextGCal()
        guard let action = gcalSyncAction else {
            task.setTaskCompleted(success: true)
            return
        }
        let work = Task { @MainActor in
            await action()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }
}
