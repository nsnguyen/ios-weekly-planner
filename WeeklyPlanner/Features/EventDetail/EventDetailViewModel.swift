import CoreLocation
import Foundation
import Observation

/// Drives the Paper Event Detail sheet for a single event.
///
/// Loads the event from `EventStoring`, derives the visible toggle state
/// from `event.reminders`, and writes mutations back through `upsert`. The
/// `cachedCoordinate` lives only for the current session — we never persist
/// geocode results so the cache always reflects the latest address typed by
/// the user.
@MainActor
@Observable
final class EventDetailViewModel {
    /// Identifier of the event being edited. Immutable for the lifetime of
    /// the VM; tapping a different event creates a fresh instance.
    let eventID: UUID

    /// Loaded event. `nil` until `load()` completes (or if the row was
    /// deleted out from under us).
    var event: Event?

    /// Mirrors `event.reminders` for the time-based alarm row.
    var alertOn: Bool = false

    /// Minutes-before value sent when `alertOn` is flipped to `true`.
    var alertMinutes: Int = 15

    /// Mirrors `event.reminders` for the geofenced "When I arrive" row.
    var locationAlertOn: Bool = false

    /// Cached geocode result for the current session. Not persisted to disk.
    var cachedCoordinate: CLLocationCoordinate2D?

    /// Localized description of the most recent load failure, if any.
    var loadError: String?

    /// Inline toast text shown when geocoding the address fails. Cleared on
    /// the next successful toggle.
    var locationGeocodeError: String?

    private let eventStore: any EventStoring
    private let geocoder: any AddressGeocoding

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - eventID: Event to load and mutate.
    ///   - eventStore: Store backing reads and writes.
    ///   - geocoder: Injected geocoder so tests can substitute a fake.
    init(eventID: UUID,
         eventStore: any EventStoring,
         geocoder: any AddressGeocoding = SystemGeocoder())
    {
        self.eventID = eventID
        self.eventStore = eventStore
        self.geocoder = geocoder
    }

    /// Fetch the event and seed the toggle state from its reminders. Errors
    /// surface via `loadError` rather than throwing so the sheet renders an
    /// inline message instead of crashing.
    func load() async {
        do {
            event = try await eventStore.event(id: eventID)
            if let event {
                if let minutes = event.reminders.first(where: { $0.isTimeBefore })?.timeBeforeMinutes {
                    alertOn = true
                    alertMinutes = minutes
                } else {
                    alertOn = false
                }
                locationAlertOn = event.reminders.contains { $0.isOnArrive }
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Add or remove the `.timeBefore` reminder on the event and persist.
    /// No-ops if the event hasn't loaded yet.
    func toggleAlert(_ on: Bool) async {
        guard let event else { return }
        var reminders = event.reminders.filter { !$0.isTimeBefore }
        if on {
            reminders.append(.timeBefore(minutes: alertMinutes))
        }
        event.reminders = reminders
        event.updatedAt = .init()
        try? await eventStore.upsert(event)
        alertOn = on
    }

    /// Add or remove the `.onArrive` reminder. Geocodes the event's location
    /// string on the first activation; subsequent toggles reuse the cached
    /// coordinate. If geocoding fails, the toggle reverts and
    /// `locationGeocodeError` is set for the toast.
    func toggleLocationAlert(_ on: Bool) async {
        guard let event, let location = event.location else {
            locationAlertOn = false
            return
        }
        var reminders = event.reminders.filter { !$0.isOnArrive }
        if on {
            if cachedCoordinate == nil {
                do {
                    cachedCoordinate = try await geocoder.geocode(address: location)
                } catch {
                    locationGeocodeError = "Couldn't find location"
                    locationAlertOn = false
                    return
                }
            }
            guard let coord = cachedCoordinate else {
                locationAlertOn = false
                return
            }
            reminders.append(.onArrive(LocationReminder(name: location,
                                                        latitude: coord.latitude,
                                                        longitude: coord.longitude,
                                                        radiusMeters: 100)))
        }
        event.reminders = reminders
        event.updatedAt = .init()
        try? await eventStore.upsert(event)
        locationAlertOn = on
        locationGeocodeError = nil
    }

    /// Remove the event from the store. The EventKit decorator in Phase 04
    /// also clears the system calendar copy.
    func delete() async {
        try? await eventStore.delete(id: eventID)
    }

    /// Suggestion text rendered in the yellow sticky inside the sheet.
    var aiSuggestion: String {
        guard let event else { return "" }
        return EventAISuggestion.text(for: event)
    }
}

// MARK: - Reminder helpers

/// File-scoped sugar over `Reminder` to keep the filter and pattern-match
/// sites in this file readable. Not exposed outside the file — every other
/// caller in the app already uses `if case` directly.
private extension Reminder {
    var isTimeBefore: Bool {
        if case .timeBefore = self { true } else { false }
    }

    var timeBeforeMinutes: Int? {
        if case let .timeBefore(minutes) = self { minutes } else { nil }
    }

    var isOnArrive: Bool {
        if case .onArrive = self { true } else { false }
    }
}

// MARK: - Geocoder protocol for testability

/// Minimal interface over `CLGeocoder` so tests can substitute a fake.
protocol AddressGeocoding: Sendable {
    func geocode(address: String) async throws -> CLLocationCoordinate2D
}

/// Production geocoder backed by `CLGeocoder`. A fresh instance is used per
/// call because `CLGeocoder` only accepts one outstanding request at a time;
/// reusing a long-lived instance from multiple call-sites would trip the
/// rate-limiter.
struct SystemGeocoder: AddressGeocoding {
    func geocode(address: String) async throws -> CLLocationCoordinate2D {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(address)
        guard let coord = placemarks.first?.location?.coordinate else {
            throw NSError(domain: "Geocoder",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No coordinates"])
        }
        return coord
    }
}
