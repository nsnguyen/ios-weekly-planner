import EventKit
import Foundation

/// Mapping between `TaskItem` and `EKReminder`. Like `EKEventMapping`,
/// pure functions only.
///
/// `EKReminder.priority` uses Apple's RFC-5545 numbering, which is NOT
/// intuitive: `0` = none, `1` = high, `5` = medium, `9` = low. We map our
/// `Priority` enum through `priorityToEK` / `priorityFromEK`.
enum EKReminderMapping {
    private static let metaMarker = "--planner-meta:"
    private static let metaEnd = "--"

    static func apply(_ task: TaskItem, to reminder: EKReminder, calendar: EKCalendar?) {
        reminder.title = task.title
        if let calendar { reminder.calendar = calendar }
        reminder.priority = priorityToEK(task.priority)
        reminder.isCompleted = task.done

        var components = Calendar.current.dateComponents([.year, .month, .day], from: task.due)
        if let time = task.reminderTime {
            let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
        }
        reminder.dueDateComponents = components
        reminder.notes = encodeNotes(forTask: task)

        if let location = task.locationReminder {
            let structuredLocation = EKStructuredLocation(title: location.name)
            structuredLocation.geoLocation = .init(latitude: location.latitude,
                                                   longitude: location.longitude)
            structuredLocation.radius = location.radiusMeters
            let alarm = EKAlarm()
            alarm.structuredLocation = structuredLocation
            alarm.proximity = .enter
            reminder.alarms = [alarm]
        }
    }

    static func toTaskItem(_ reminder: EKReminder,
                           defaultCategory: Category = .personal,
                           existingID: UUID? = nil) -> TaskItem
    {
        let meta = decodeMeta(from: reminder.notes ?? "")
        let due = reminder.dueDateComponents?.date ?? Date()
        let locationAlarm = reminder.alarms?.first { $0.structuredLocation != nil }

        return TaskItem(id: existingID ?? UUID(),
                        eventKitReminderID: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "",
                        due: due,
                        done: reminder.isCompleted,
                        priority: priorityFromEK(reminder.priority),
                        category: meta?.category ?? defaultCategory,
                        reminderText: meta?.reminderText,
                        locationReminder: locationAlarm.flatMap { alarm in
                            guard
                                let location = alarm.structuredLocation,
                                let coord = location.geoLocation
                            else { return nil }
                            return LocationReminder(name: location.title ?? "",
                                                    latitude: coord.coordinate.latitude,
                                                    longitude: coord.coordinate.longitude,
                                                    radiusMeters: location.radius)
                        })
    }

    // MARK: - Priority codec

    /// Our priority → EKReminder.priority (RFC 5545).
    static func priorityToEK(_ priority: Priority) -> Int {
        switch priority {
        case .high: 1
        case .med: 5
        case .low: 9
        }
    }

    /// EKReminder.priority → our priority. 0 (none) and any unknown value
    /// fall back to `.med`. Anything ≤ 3 is high; ≥ 7 is low; middle is med.
    static func priorityFromEK(_ value: Int) -> Priority {
        switch value {
        case 1 ... 3: .high
        case 4 ... 6: .med
        case 7 ... 9: .low
        default: .med
        }
    }

    // MARK: - Notes meta

    private struct Meta: Codable {
        let category: Category?
        let reminderText: String?
    }

    private static func encodeNotes(forTask task: TaskItem) -> String {
        let meta = Meta(category: task.category, reminderText: task.reminderText)
        guard
            let data = try? JSONEncoder().encode(meta),
            let json = String(data: data, encoding: .utf8)
        else { return "" }
        return "\(metaMarker)\(json)\(metaEnd)"
    }

    static func decodeMeta(from notes: String) -> (category: Category?, reminderText: String?)? {
        guard
            let markerRange = notes.range(of: metaMarker),
            let endRange = notes.range(of: metaEnd, range: markerRange.upperBound ..< notes.endIndex)
        else { return nil }
        let payload = notes[markerRange.upperBound ..< endRange.lowerBound]
        guard
            let data = payload.data(using: .utf8),
            let meta = try? JSONDecoder().decode(Meta.self, from: data)
        else { return nil }
        return (meta.category, meta.reminderText)
    }
}
