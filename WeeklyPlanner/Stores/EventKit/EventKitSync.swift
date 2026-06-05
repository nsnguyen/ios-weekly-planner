import EventKit
import Foundation
import SwiftData

/// State exposed to Settings + the sync UI affordance.
enum SyncState: Equatable {
    case idle
    case running
    case failed(message: String)
}

/// Reconciles SwiftData and EventKit. Runs once on launch (post-permission)
/// and again on every `EKEventStoreChanged` notification.
///
/// Resolution rule: **last-write-wins by `updatedAt`** for events; for
/// reminders we trust `EKReminder.isCompleted` if it changed externally.
@MainActor
@Observable
final class EventKitSync {
    private(set) var state: SyncState = .idle

    private let gateway: any EventKitGateway
    private let calendarManager: CategoryCalendarManager
    private let eventStore: any EventStoring
    private let taskStore: any TaskStoring

    /// Sync window. Two months back, four months forward.
    var windowStart: Date {
        Calendar.current.date(byAdding: .day, value: -8 * 7, to: Date()) ?? Date()
    }

    var windowEnd: Date {
        Calendar.current.date(byAdding: .day, value: 16 * 7, to: Date()) ?? Date()
    }

    init(gateway: any EventKitGateway,
         calendarManager: CategoryCalendarManager,
         eventStore: any EventStoring,
         taskStore: any TaskStoring)
    {
        self.gateway = gateway
        self.calendarManager = calendarManager
        self.eventStore = eventStore
        self.taskStore = taskStore
    }

    /// One-shot reconcile. Safe to call concurrently — re-entrancy is
    /// avoided by serializing on `@MainActor`.
    func reconcile() async {
        guard gateway.eventsAuthStatus.isFullAccess else {
            state = .failed(message: "Events access not granted")
            return
        }
        state = .running
        do {
            try calendarManager.ensureCalendars()
            try await reconcileEvents()
            if gateway.remindersAuthStatus.isFullAccess {
                try await reconcileReminders()
            }
            state = .idle
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    /// Subscribes to EventKit change notifications and triggers a sync on
    /// every one. The task lives for the lifetime of the caller.
    func observeChanges() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }
            for await _ in await gateway.changes {
                await reconcile()
            }
        }
    }

    // MARK: - Events

    private func reconcileEvents() async throws {
        let plannerCalendars = try calendarManager.ensureCalendars()
        let allCalendars = Array(plannerCalendars.values)
        let ekEvents = gateway.fetchEvents(from: windowStart, to: windowEnd, calendars: allCalendars)

        // Snapshot every local event in the window so we can detect deletes.
        var seenIdentifiers: Set<String> = []

        // A recurring EKEvent enumerates one instance per occurrence, all
        // sharing the same `eventIdentifier`. Group them and reconcile each
        // series once from its earliest (canonical) instance so a later
        // occurrence can't thrash the master's anchor.
        let grouped = Dictionary(grouping: ekEvents.filter { $0.eventIdentifier != nil }) {
            $0.eventIdentifier ?? UUID().uuidString
        }
        for (identifier, instances) in grouped {
            guard let ekEvent = instances.min(by: { $0.startDate < $1.startDate }) else { continue }
            seenIdentifiers.insert(identifier)

            let inferredCategory = ekEvent.calendar.flatMap(CategoryCalendarManager.category(for:)) ?? .personal
            let mapped = EKEventMapping.toEvent(ekEvent, defaultCategory: inferredCategory)

            // Look up existing local event by EventKit identifier. For a
            // recurring series, `fetchLocalEvent` yields a transient occurrence
            // copy — resolve it back to the persisted master before mutating.
            if let matched = try await fetchLocalEvent(forEventKitID: identifier),
               let existing = try await eventStore.event(id: matched.id)
            {
                if (ekEvent.lastModifiedDate ?? .distantPast) > existing.updatedAt {
                    existing.title = mapped.title
                    // A recurring app event keeps its own anchor dates +
                    // recurrence rule: an externally-moved series anchor won't
                    // re-anchor the app copy (stated Phase 35 limit).
                    if !existing.isRecurring {
                        existing.start = mapped.start
                        existing.end = mapped.end
                        existing.recurrence = mapped.recurrence
                        existing.isRecurring = mapped.recurrence != nil
                    }
                    existing.location = mapped.location
                    existing.categoryRaw = mapped.categoryRaw
                    existing.attendeesCount = mapped.attendeesCount
                    existing.sourceRaw = mapped.sourceRaw
                    existing.gmailMessageID = mapped.gmailMessageID
                    existing.gmailFrom = mapped.gmailFrom
                    existing.gmailSubject = mapped.gmailSubject
                    existing.reminders = mapped.reminders
                    existing.updatedAt = .init()
                }
            } else {
                mapped.eventKitIdentifier = identifier
                try await eventStore.upsert(mapped)
            }
        }

        // TODO: Phase 11: delete locally any events not seen in EK (and not
        // recently created locally). For v1 we keep both copies until the
        // user explicitly deletes.
    }

    /// Fetches a local Event by its EventKit identifier across the whole
    /// window (the store's `event(id:)` keys on our own UUID, not EK's).
    private func fetchLocalEvent(forEventKitID eventKitID: String) async throws -> Event? {
        for offset in -8 ... 16 {
            let weekly = try await eventStore.events(forWeekOffset: offset, today: Date())
            if let match = weekly.first(where: { $0.eventKitIdentifier == eventKitID }) {
                return match
            }
        }
        return nil
    }

    // MARK: - Reminders

    private func reconcileReminders() async throws {
        let reminders = await gateway.fetchReminders(in: nil)
        for ekReminder in reminders {
            let identifier = ekReminder.calendarItemIdentifier
            let mapped = EKReminderMapping.toTaskItem(ekReminder)

            if let existing = try await fetchLocalTask(forReminderID: identifier) {
                if (ekReminder.lastModifiedDate ?? .distantPast) > existing.updatedAt {
                    existing.title = mapped.title
                    existing.due = mapped.due
                    existing.done = mapped.done
                    existing.priorityRaw = mapped.priorityRaw
                    existing.categoryRaw = mapped.categoryRaw
                    existing.reminderText = mapped.reminderText
                    existing.locationReminder = mapped.locationReminder
                    existing.updatedAt = .init()
                }
            } else {
                mapped.eventKitReminderID = identifier
                try await taskStore.upsert(mapped)
            }
        }
    }

    private func fetchLocalTask(forReminderID reminderID: String) async throws -> TaskItem? {
        for offset in -8 ... 16 {
            let weekly = try await taskStore.tasks(forWeekOffset: offset, today: Date())
            if let match = weekly.first(where: { $0.eventKitReminderID == reminderID }) {
                return match
            }
        }
        return nil
    }
}
