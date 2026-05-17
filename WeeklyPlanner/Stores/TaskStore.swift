import Foundation
import SwiftData

@MainActor
protocol TaskStoring: AnyObject {
    func tasks(forWeekOffset offset: Int, today: Date) async throws -> [TaskItem]
    func task(id: UUID) async throws -> TaskItem?
    func upsert(_ task: TaskItem) async throws
    func toggle(id: UUID) async throws
    func delete(id: UUID) async throws
}

@MainActor
final class SwiftDataTaskStore: TaskStoring {
    private let context: ModelContext
    private let changeSubject = NotificationCenter.default

    init(context: ModelContext) {
        self.context = context
    }

    func tasks(forWeekOffset offset: Int, today: Date = .init()) async throws -> [TaskItem] {
        let bounds = SwiftDataEventStore.weekBounds(forOffset: offset, today: today)
        let start = bounds.start
        let end = bounds.end
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate<TaskItem> { $0.due >= start && $0.due < end },
                                                   sortBy: [SortDescriptor(\.due, order: .forward)])
        return try context.fetch(descriptor)
    }

    func task(id: UUID) async throws -> TaskItem? {
        try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate<TaskItem> { $0.id == id })).first
    }

    func upsert(_ task: TaskItem) async throws {
        let id = task.id
        let existing = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate<TaskItem> { $0.id == id }))
            .first

        if let existing {
            existing.title = task.title
            existing.due = task.due
            existing.done = task.done
            existing.priorityRaw = task.priorityRaw
            existing.categoryRaw = task.categoryRaw
            existing.reminderText = task.reminderText
            existing.reminderTime = task.reminderTime
            existing.locationReminder = task.locationReminder
            existing.eventKitReminderID = task.eventKitReminderID
            existing.updatedAt = .init()
        } else {
            context.insert(task)
        }
        try context.save()
        changeSubject.post(name: .taskStoreDidChange, object: nil)
    }

    func toggle(id: UUID) async throws {
        guard let task = try await task(id: id) else { return }
        task.done.toggle()
        task.updatedAt = .init()
        try context.save()
        changeSubject.post(name: .taskStoreDidChange, object: nil)
    }

    func delete(id: UUID) async throws {
        guard let task = try await task(id: id) else { return }
        context.delete(task)
        try context.save()
        changeSubject.post(name: .taskStoreDidChange, object: nil)
    }
}

extension Notification.Name {
    static let taskStoreDidChange = Notification.Name("WeeklyPlanner.TaskStore.didChange")
}
