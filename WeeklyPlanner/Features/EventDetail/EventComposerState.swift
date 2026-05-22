import Foundation
import Observation

/// Editable draft for a new or existing `Event`. Carries the visible
/// composer fields, validation predicates, and helpers to round-trip
/// to/from `Event`.
///
/// Held by `EventDetailViewModel` while the sheet is in `.edit` or
/// `.create` mode; nil in `.view` mode. The view binds to fields via
/// `@Bindable` so `TextField` / `DatePicker` two-way bindings work.
@MainActor
@Observable
final class EventComposerState {
    var title: String
    var start: Date
    var end: Date
    var category: Category
    var location: String
    var alertOn: Bool
    var alertMinutes: Int
    var locationAlertOn: Bool

    /// Reminders attached to the source event that the composer's UI does
    /// not expose for editing (`.onArrive` payloads, any `.timeBefore` past
    /// the first). Preserved verbatim so `build()` doesn't erase a geofence
    /// or a second alert on save.
    private var preservedReminders: [Reminder] = []

    init(title: String,
         start: Date,
         end: Date,
         category: Category,
         location: String,
         alertOn: Bool,
         alertMinutes: Int,
         locationAlertOn: Bool)
    {
        self.title = title
        self.start = start
        self.end = end
        self.category = category
        self.location = location
        self.alertOn = alertOn
        self.alertMinutes = alertMinutes
        self.locationAlertOn = locationAlertOn
    }

    /// `start` snapped to the next hour boundary after `date`; `end` =
    /// `start + 1h`; everything else empty/default.
    static func empty(at date: Date, calendar: Calendar) -> EventComposerState {
        let nextHour = calendar.nextDate(after: date,
                                          matching: DateComponents(minute: 0, second: 0),
                                          matchingPolicy: .nextTime) ?? date.addingTimeInterval(3600)
        return EventComposerState(title: "",
                                  start: nextHour,
                                  end: nextHour.addingTimeInterval(3600),
                                  category: .personal,
                                  location: "",
                                  alertOn: false,
                                  alertMinutes: 15,
                                  locationAlertOn: false)
    }

    /// Hydrate from an existing `Event`. The composer reads the time-before
    /// minutes off the first `.timeBefore` reminder, mirroring the same
    /// logic `EventDetailViewModel.load()` uses. Reminders the composer UI
    /// doesn't surface (`.onArrive` payloads, secondary `.timeBefore`
    /// alarms) are captured into `preservedReminders` so a round-trip
    /// through `build()` doesn't erase them.
    static func from(_ event: Event) -> EventComposerState {
        var alertOn = false
        var alertMinutes = 15
        var didCaptureFirstTimeBefore = false
        var preserved: [Reminder] = []

        for reminder in event.reminders {
            switch reminder {
            case let .timeBefore(minutes):
                if !didCaptureFirstTimeBefore {
                    alertOn = true
                    alertMinutes = minutes
                    didCaptureFirstTimeBefore = true
                } else {
                    preserved.append(reminder)
                }
            case .onArrive:
                preserved.append(reminder)
            }
        }
        let locationAlertOn = event.reminders.contains {
            if case .onArrive = $0 { true } else { false }
        }
        let state = EventComposerState(title: event.title,
                                       start: event.start,
                                       end: event.end,
                                       category: event.category,
                                       location: event.location ?? "",
                                       alertOn: alertOn,
                                       alertMinutes: alertMinutes,
                                       locationAlertOn: locationAlertOn)
        state.preservedReminders = preserved
        return state
    }

    var titleIsValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var timesAreValid: Bool { end > start }

    var canSave: Bool { titleIsValid && timesAreValid }

    /// Field-by-field comparison against another composer instance held as
    /// a baseline by the caller (typically a snapshot taken at the moment
    /// editing began). We don't rely on object identity — the controller
    /// is free to construct two independent composers from the same source.
    func isDirty(against other: EventComposerState) -> Bool {
        title != other.title
            || start != other.start
            || end != other.end
            || category != other.category
            || location != other.location
            || alertOn != other.alertOn
            || alertMinutes != other.alertMinutes
            || locationAlertOn != other.locationAlertOn
            || preservedReminders.map(reminderKey) != other.preservedReminders.map(reminderKey)
    }

    private func reminderKey(_ r: Reminder) -> String {
        switch r {
        case let .timeBefore(minutes): return "t:\(minutes)"
        case let .onArrive(loc): return "a:\(loc.name):\(loc.latitude):\(loc.longitude):\(loc.radiusMeters)"
        }
    }

    /// Build a fresh `Event` from the current draft. Caller supplies the
    /// ID (defaults to a new UUID for `.create`; pass the existing event's
    /// ID for `.edit`).
    ///
    /// Note: `.onArrive` reminders are NOT emitted by the composer's own
    /// fields — they require a geocoded coordinate and live on
    /// `EventDetailViewModel.toggleLocationAlert`. However, any `.onArrive`
    /// payload captured by `from(_:)` into `preservedReminders` is
    /// re-emitted here so a save round-trip doesn't erase the geofence.
    /// If the user toggled `locationAlertOn` off in the composer, the
    /// preserved `.onArrive` is dropped instead.
    func build(id: UUID = UUID()) -> Event {
        var reminders: [Reminder] = []
        if alertOn {
            reminders.append(.timeBefore(minutes: alertMinutes))
        }
        // Filter preserved reminders based on the composer's current toggle
        // state. If `locationAlertOn` is false, drop any preserved
        // `.onArrive` — the user explicitly turned it off. Secondary
        // `.timeBefore` alarms are always preserved.
        let filteredPreserved = preservedReminders.filter { reminder in
            switch reminder {
            case .onArrive: return locationAlertOn
            case .timeBefore: return true
            }
        }
        reminders.append(contentsOf: filteredPreserved)

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return Event(id: id,
                     title: trimmedTitle,
                     start: start,
                     end: end,
                     location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                     category: category,
                     source: .manual,
                     reminders: reminders)
    }
}
