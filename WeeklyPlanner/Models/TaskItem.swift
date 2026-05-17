import Foundation
import SwiftData

/// One to-do. Named `TaskItem` (not `Task`) because Swift's structured
/// concurrency `Task` type would otherwise collide everywhere.
///
/// Synced to Apple Reminders via EventKit (Phase 04) once the user grants
/// permission. Like `Event`, EventKit-specific fields are nullable so a
/// fresh task that hasn't been pushed yet is still valid.
@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID

    /// `EKReminder.calendarItemIdentifier` once the task has been pushed to
    /// or pulled from the system Reminders app.
    var eventKitReminderID: String?

    var title: String

    /// Date-only by convention; `reminderTime` carries the optional clock time.
    var due: Date

    var done: Bool

    var priorityRaw: String
    var categoryRaw: String

    /// Free-form reminder hint shown on the to-do row, e.g.,
    /// `"When I arrive at Marina"`. Distinct from `reminderTime` because the
    /// user might type it and not commit to a concrete alarm.
    var reminderText: String?

    /// Exact alarm time if the user committed to one.
    var reminderTime: Date?

    /// Geofenced reminder, stored as a JSON blob by SwiftData.
    var locationReminder: LocationReminder?

    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         eventKitReminderID: String? = nil,
         title: String,
         due: Date,
         done: Bool = false,
         priority: Priority = .med,
         category: Category,
         reminderText: String? = nil,
         reminderTime: Date? = nil,
         locationReminder: LocationReminder? = nil,
         createdAt: Date = .init(),
         updatedAt: Date = .init())
    {
        self.id = id
        self.eventKitReminderID = eventKitReminderID
        self.title = title
        self.due = due
        self.done = done
        priorityRaw = priority.rawValue
        categoryRaw = category.rawValue
        self.reminderText = reminderText
        self.reminderTime = reminderTime
        self.locationReminder = locationReminder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension TaskItem {
    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .med }
        set { priorityRaw = newValue.rawValue }
    }

    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .personal }
        set { categoryRaw = newValue.rawValue }
    }

    /// Number of weeks from the start of `base`'s week to the start of `due`'s
    /// week. Used to bucket tasks into the same week-strip view that shows
    /// events. Monday-based.
    func weekOffset(from base: Date, calendar: Calendar = .current) -> Int {
        let baseStart = calendar.startOfWeekMondayBased(for: base)
        let dueStart = calendar.startOfWeekMondayBased(for: due)
        let components = calendar.dateComponents([.weekOfYear], from: baseStart, to: dueStart)
        return components.weekOfYear ?? 0
    }
}

extension Calendar {
    /// Monday-based start-of-week. Independent of `firstWeekday` so tasks
    /// always bucket consistently with the planner view.
    func startOfWeekMondayBased(for date: Date) -> Date {
        let weekday = component(.weekday, from: date)
        let daysSinceMonday = (weekday + 5) % 7
        let monday = self.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay(for: date))
        return monday ?? startOfDay(for: date)
    }
}
