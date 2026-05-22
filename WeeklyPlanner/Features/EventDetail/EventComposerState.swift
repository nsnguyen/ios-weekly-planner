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
    /// logic `EventDetailViewModel.load()` uses.
    static func from(_ event: Event) -> EventComposerState {
        var alertOn = false
        var alertMinutes = 15
        for reminder in event.reminders {
            if case let .timeBefore(minutes) = reminder {
                alertOn = true
                alertMinutes = minutes
                break
            }
        }
        let locationAlertOn = event.reminders.contains {
            if case .onArrive = $0 { true } else { false }
        }
        return EventComposerState(title: event.title,
                                  start: event.start,
                                  end: event.end,
                                  category: event.category,
                                  location: event.location ?? "",
                                  alertOn: alertOn,
                                  alertMinutes: alertMinutes,
                                  locationAlertOn: locationAlertOn)
    }

    var titleIsValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var timesAreValid: Bool { end > start }

    var canSave: Bool { titleIsValid && timesAreValid }

    /// Snapshot used by `isDirty(against:)`. Field-by-field comparison;
    /// we don't compare object identity.
    func isDirty(against other: EventComposerState) -> Bool {
        title != other.title
            || start != other.start
            || end != other.end
            || category != other.category
            || location != other.location
            || alertOn != other.alertOn
            || alertMinutes != other.alertMinutes
            || locationAlertOn != other.locationAlertOn
    }

    /// Build a fresh `Event` from the current draft. Caller supplies the
    /// ID (defaults to a new UUID for `.create`; pass the existing event's
    /// ID for `.edit`).
    func build(id: UUID = UUID()) -> Event {
        var reminders: [Reminder] = []
        if alertOn {
            reminders.append(.timeBefore(minutes: alertMinutes))
        }
        // Note: `.onArrive` reminders are NOT built here. They require a
        // geocoded coordinate and live on `EventDetailViewModel.toggleLocationAlert`.
        // Composer-driven creates skip the location alert at first save;
        // the user can flip it on after the event exists.
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
