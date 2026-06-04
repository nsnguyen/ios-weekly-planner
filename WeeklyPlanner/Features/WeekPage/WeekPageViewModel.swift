import Foundation
import Observation

/// Drives the Hobonichi-style week page for a single `weekOffset`.
///
/// Owns the week's 7-day strip plus a per-weekday slice of events and to-dos,
/// and a pending-inbox count used by the sticky note on the bottom-right. The
/// view triggers `refresh()` from `.task` on appear and after every mutation;
/// real-time `AsyncStream` observation is deferred until SwiftData `@Model`
/// types are `Sendable` across actor hops (mirroring `DayPageViewModel`).
///
/// All store calls are `@MainActor`-isolated, so this class is too.
@MainActor
@Observable
final class WeekPageViewModel {
    /// Week relative to "today's week" (0 = current, -1 = last, +1 = next).
    let weekOffset: Int

    /// Seven `WeekDay` values, Monday-first, for the week at `weekOffset`.
    var days: [WeekDay] = []

    /// Events keyed by Monday-based weekday index (0 = Mon … 6 = Sun). Each
    /// bucket is sorted ascending by `start`. Empty buckets are omitted.
    var eventsByDay: [Int: [Event]] = [:]

    /// To-dos keyed by Monday-based weekday index. Each bucket is sorted
    /// high-priority-first then alphabetical by title for stability.
    ///
    /// As of Phase 30 (#26) the week spread renders events only, so no week
    /// view consumes these buckets — the data layer is intentionally
    /// untouched (tasks remain first-class on the Day page). The header's
    /// former `eventCount`/`openTaskCount` lines were pruned with it (#29).
    var tasksByDay: [Int: [TaskItem]] = [:]

    /// Total pending inbox suggestions whose `proposedStart` falls inside the
    /// week. Surfaced in the bottom-right sticky note for the current week.
    var inboxCount: Int = 0

    /// Localized description of the most recent fetch failure, if any.
    var loadError: String?

    private let eventStore: any EventStoring
    private let taskStore: any TaskStoring
    private let inboxStore: any InboxStoring
    private let clock: () -> Date

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - weekOffset: Week relative to "now" (0 = current week).
    ///   - eventStore: Store for `Event` reads.
    ///   - taskStore: Store for `TaskItem` reads and `toggle` mutations.
    ///   - inboxStore: Store for `InboxSuggestion` pending reads.
    ///   - clock: Injected "now" so tests can pin the date. Defaults to
    ///     `Date()` in production.
    init(weekOffset: Int,
         eventStore: any EventStoring,
         taskStore: any TaskStoring,
         inboxStore: any InboxStoring,
         clock: @escaping () -> Date = { .init() })
    {
        self.weekOffset = weekOffset
        self.eventStore = eventStore
        self.taskStore = taskStore
        self.inboxStore = inboxStore
        self.clock = clock
    }

    /// Triggered by pull-to-refresh on the Week page. Delegates to the
    /// shared `InboxSyncEngine`. Errors are swallowed (user-facing state
    /// is just "no new suggestions appeared").
    func refresh(via engine: InboxSyncEngine?) async {
        guard let engine else { return }
        _ = try? await engine.sync(now: Date())
        // After a successful sync, re-fetch suggestions for the current week.
        await refresh()
    }

    /// Re-fetch events + tasks + the pending-inbox count for the week and
    /// group them by Monday-based weekday index. Errors from any store are
    /// surfaced via `loadError` while previously-loaded data is left in place
    /// (matches `DayPageViewModel`'s policy).
    func refresh() async {
        let calendar = WeekMath.mondayCalendar()
        let now = clock()
        days = WeekMath.weekDays(forOffset: weekOffset, today: now)

        do {
            let allEvents = try await eventStore.events(forWeekOffset: weekOffset, today: now)
            var grouped: [Int: [Event]] = [:]
            for event in allEvents {
                let idx = event.weekdayIndex(in: calendar)
                grouped[idx, default: []].append(event)
            }
            for idx in grouped.keys {
                grouped[idx]?.sort { $0.start < $1.start }
            }
            eventsByDay = grouped
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }

        do {
            let allTasks = try await taskStore.tasks(forWeekOffset: weekOffset, today: now)
            var grouped: [Int: [TaskItem]] = [:]
            for task in allTasks {
                let idx = task.due.mondayBasedWeekdayIndex(in: calendar)
                grouped[idx, default: []].append(task)
            }
            for idx in grouped.keys {
                grouped[idx]?.sort { lhs, rhs in
                    if lhs.priority != rhs.priority {
                        return lhs.priority.sortWeight > rhs.priority.sortWeight
                    }
                    return lhs.title < rhs.title
                }
            }
            tasksByDay = grouped
        } catch {
            loadError = error.localizedDescription
        }

        do {
            let pending = try await inboxStore.pending(forWeekOffset: weekOffset, today: now)
            inboxCount = pending.count
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Flip the `done` flag on the task with the given id and refresh.
    /// Errors swallow into `loadError` so the row never throws into SwiftUI.
    func toggleTask(id: UUID) async {
        do {
            try await taskStore.toggle(id: id)
        } catch {
            loadError = error.localizedDescription
        }
        await refresh()
    }
}

private extension Date {
    /// Monday-based weekday index (0 = Mon … 6 = Sun). Mirrors
    /// `Event.weekdayIndex(in:)` for non-`Event` date values. Duplicated from
    /// `DayPageViewModel.swift` to keep the two view models independent.
    func mondayBasedWeekdayIndex(in calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: self)
        return (weekday + 5) % 7
    }
}
