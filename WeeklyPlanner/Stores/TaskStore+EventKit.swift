import EventKit
import Foundation

/// Decorator that mirrors `TaskItem` writes through to EventKit's Reminders.
/// Mirrors the design of `EventKitMirroringEventStore` — SwiftData is the
/// source of truth, EventKit is the side channel.
@MainActor
final class EventKitMirroringTaskStore: TaskStoring {
    private let base: any TaskStoring
    private let gateway: any EventKitGateway

    init(base: any TaskStoring, gateway: any EventKitGateway) {
        self.base = base
        self.gateway = gateway
    }

    func tasks(forWeekOffset offset: Int, today: Date) async throws -> [TaskItem] {
        try await base.tasks(forWeekOffset: offset, today: today)
    }

    func task(id: UUID) async throws -> TaskItem? {
        try await base.task(id: id)
    }

    func upsert(_ task: TaskItem) async throws {
        try await base.upsert(task)
        try? await mirrorToEventKit(task)
    }

    func toggle(id: UUID) async throws {
        try await base.toggle(id: id)
        if let updated = try await base.task(id: id) {
            try? await mirrorToEventKit(updated)
        }
    }

    func delete(id: UUID) async throws {
        if let task = try await base.task(id: id),
           let identifier = task.eventKitReminderID
        {
            removeFromEventKit(identifier: identifier)
        }
        try await base.delete(id: id)
    }

    // MARK: - EventKit side effects

    private func mirrorToEventKit(_ task: TaskItem) async throws {
        guard gateway.remindersAuthStatus.isFullAccess else { return }

        let reminder: EKReminder
        if let identifier = task.eventKitReminderID,
           let existing = await gateway.fetchReminders(in: nil)
           .first(where: { $0.calendarItemIdentifier == identifier })
        {
            reminder = existing
        } else {
            reminder = gateway.newReminder()
            reminder.calendar = gateway.defaultReminderCalendar ?? reminder.calendar
        }

        EKReminderMapping.apply(task, to: reminder, calendar: reminder.calendar)
        try gateway.save(reminder)

        if task.eventKitReminderID == nil {
            task.eventKitReminderID = reminder.calendarItemIdentifier
            try? await base.upsert(task)
        }
    }

    private func removeFromEventKit(identifier: String) {
        guard gateway.remindersAuthStatus.isFullAccess else { return }
        Task { [gateway] in
            let reminders = await gateway.fetchReminders(in: nil)
            if let match = reminders.first(where: { $0.calendarItemIdentifier == identifier }) {
                try? gateway.remove(match)
            }
        }
    }
}
