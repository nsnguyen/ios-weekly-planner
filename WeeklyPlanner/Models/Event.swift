import Foundation
import SwiftData
import SwiftUI

/// Canonical event record. Persisted in SwiftData, mirrored to EventKit
/// (Phase 04), and read by every view that shows calendar data.
///
/// EventKit-specific fields (`eventKitIdentifier`, `gmail*`) are nullable so
/// manual events that have never touched EventKit still validate.
@Model
final class Event {
    @Attribute(.unique) var id: UUID

    /// `EKEvent.eventIdentifier` once the event has been pushed to or pulled
    /// from the system Calendar. `nil` for events that exist only locally.
    var eventKitIdentifier: String?

    var title: String
    var start: Date
    var end: Date
    var location: String?

    /// Free-form user-authored notes. Round-tripped to `EKEvent.notes`
    /// alongside the planner-meta marker. `nil` when the user hasn't
    /// written anything (so an empty edit doesn't fight an existing
    /// third-party note).
    var notes: String?

    /// Stored as String raw value so SwiftData predicates can filter on it
    /// directly (`#Predicate { $0.categoryRaw == "work" }`).
    var categoryRaw: String

    var attendeesCount: Int

    /// Pre-calculated travel time in minutes. Populated by Phase 18's Gmail
    /// pipeline or by the user manually editing the event.
    var travelMinutes: Int?

    var sourceRaw: String

    // MARK: Gmail provenance (Phase 18)

    var gmailMessageID: String?
    var gmailFrom: String?
    var gmailSubject: String?

    /// Reminders attached to this event. Stored as a JSON-encoded blob by
    /// SwiftData because `Reminder` is a Codable enum with associated values.
    var reminders: [Reminder]

    /// Phase 35: repeat rule. `nil` = single occurrence.
    var recurrence: Recurrence?
    /// Predicate-friendly mirror of `recurrence != nil` (SwiftData can't
    /// filter on the Codable column). Maintained by init and the store.
    var isRecurring: Bool = false
    /// Occurrence starts the user deleted individually ("this event only").
    var excludedOccurrenceStarts: [Date] = []

    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         eventKitIdentifier: String? = nil,
         title: String,
         start: Date,
         end: Date,
         location: String? = nil,
         notes: String? = nil,
         category: Category,
         attendeesCount: Int = 0,
         travelMinutes: Int? = nil,
         source: EventSource = .manual,
         gmailMessageID: String? = nil,
         gmailFrom: String? = nil,
         gmailSubject: String? = nil,
         reminders: [Reminder] = [],
         recurrence: Recurrence? = nil,
         excludedOccurrenceStarts: [Date] = [],
         createdAt: Date = .init(),
         updatedAt: Date = .init())
    {
        self.id = id
        self.eventKitIdentifier = eventKitIdentifier
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.notes = notes
        categoryRaw = category.rawValue
        self.attendeesCount = attendeesCount
        self.travelMinutes = travelMinutes
        sourceRaw = source.rawValue
        self.gmailMessageID = gmailMessageID
        self.gmailFrom = gmailFrom
        self.gmailSubject = gmailSubject
        self.reminders = reminders
        self.recurrence = recurrence
        isRecurring = recurrence != nil
        self.excludedOccurrenceStarts = excludedOccurrenceStarts
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Event {
    /// Transient display copy for one occurrence of a recurring series —
    /// same `id` as the master; NEVER insert into a ModelContext.
    func occurrenceCopy(start occurrenceStart: Date) -> Event {
        let duration = end.timeIntervalSince(start)
        return Event(id: id,
                     eventKitIdentifier: eventKitIdentifier,
                     title: title,
                     start: occurrenceStart,
                     end: occurrenceStart.addingTimeInterval(duration),
                     location: location,
                     notes: notes,
                     category: category,
                     attendeesCount: attendeesCount,
                     travelMinutes: travelMinutes,
                     source: source,
                     gmailMessageID: gmailMessageID,
                     gmailFrom: gmailFrom,
                     gmailSubject: gmailSubject,
                     reminders: reminders,
                     recurrence: recurrence,
                     excludedOccurrenceStarts: excludedOccurrenceStarts,
                     createdAt: createdAt,
                     updatedAt: updatedAt)
    }
}

extension Event {
    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .personal }
        set { categoryRaw = newValue.rawValue }
    }

    var source: EventSource {
        get { EventSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /// Duration in hours (fractional). `2:30` → `2.5`.
    var durationHours: Double {
        end.timeIntervalSince(start) / 3600.0
    }

    /// Monday-based weekday index (0 = Monday … 6 = Sunday).
    func weekdayIndex(in calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: start)
        return (weekday + 5) % 7
    }

    /// Per-category handwritten-pen color for this event under `theme`.
    func inkColor(theme: PaperTheme) -> Color {
        CategoryPalette.inkColor(category, in: theme)
    }
}
