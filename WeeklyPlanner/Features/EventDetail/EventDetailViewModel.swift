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

    /// Live AI suggestion produced by `EventSuggestionGenerator`. `nil`
    /// while the model is still warming up or the device can't run AI;
    /// the `aiSuggestion` accessor falls back to the canned table in
    /// that case so the sticky never renders empty.
    var liveSuggestion: String?

    /// Active composer draft, or `nil` when the sheet is in `.view` mode.
    /// Mutating `composer` mid-edit (e.g., user types in the title field)
    /// triggers the surrounding `@Observable` propagation.
    var composer: EventComposerState?

    /// Snapshot of the composer at the time editing began. Used to detect
    /// dirty state for the discard-confirm dialog.
    private(set) var composerBaseline: EventComposerState?

    private let eventStore: any EventStoring
    private let geocoder: any AddressGeocoding
    private let suggestionGenerator: EventSuggestionGenerator?

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - eventID: Event to load and mutate.
    ///   - eventStore: Store backing reads and writes.
    ///   - geocoder: Injected geocoder so tests can substitute a fake.
    ///   - suggestionGenerator: Optional generator. Pass `nil` (default)
    ///     in tests / previews; the host injects a real one wired to
    ///     `PlannerLanguageModel` for production.
    init(eventID: UUID,
         eventStore: any EventStoring,
         geocoder: any AddressGeocoding = SystemGeocoder(),
         suggestionGenerator: EventSuggestionGenerator? = nil)
    {
        self.eventID = eventID
        self.eventStore = eventStore
        self.geocoder = geocoder
        self.suggestionGenerator = suggestionGenerator
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

    /// Switch into `.edit` mode by hydrating a composer from the loaded
    /// event. No-op if the event hasn't loaded yet.
    func beginEditing() {
        guard let event else { return }
        composer = EventComposerState.from(event)
        composerBaseline = EventComposerState.from(event)
    }

    /// Switch into `.create` mode with an empty composer anchored at
    /// `date` (the page's focused day).
    func beginCreating(at date: Date, calendar: Calendar) {
        composer = EventComposerState.empty(at: date, calendar: calendar)
        composerBaseline = EventComposerState.empty(at: date, calendar: calendar)
    }

    /// `true` iff `composer` differs from `composerBaseline`. Drives the
    /// discard-confirm dialog when the user taps Cancel.
    var composerIsDirty: Bool {
        guard let composer, let composerBaseline else { return false }
        return composer.isDirty(against: composerBaseline)
    }

    /// Commit the composer draft. In `.edit` mode this updates the
    /// existing event by id; in `.create` mode it inserts a new event.
    /// Clears the composer on success so the sheet flips back to `.view`.
    func save() async {
        guard let composer, composer.canSave else { return }
        let built = composer.build(id: event?.id ?? UUID())
        // Preserve eventKitIdentifier on edit so the mirror updates the
        // existing iOS calendar row instead of inserting a duplicate.
        built.eventKitIdentifier = event?.eventKitIdentifier
        do {
            try await eventStore.upsert(built)
            event = try await eventStore.event(id: built.id)
            // Re-seed reminder mirrors from the saved event so the alert
            // rows reflect what's on disk.
            if let event {
                alertOn = event.reminders.contains {
                    if case .timeBefore = $0 { true } else { false }
                }
                locationAlertOn = event.reminders.contains {
                    if case .onArrive = $0 { true } else { false }
                }
            }
            self.composer = nil
            composerBaseline = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Discard composer changes. Caller is responsible for the
    /// confirmation prompt; this method just clears state.
    func cancelEditing() {
        composer = nil
        composerBaseline = nil
    }

    /// Suggestion text rendered in the yellow sticky inside the sheet.
    /// Prefers the live AI-generated string when one has arrived; falls
    /// back to the canned table from Phase 11 otherwise so the sticky is
    /// never empty.
    var aiSuggestion: String {
        guard let event else { return "" }
        if let live = liveSuggestion, !live.isEmpty {
            return live
        }
        return EventAISuggestion.text(for: event)
    }

    /// Async hook the sheet calls on appear. Runs the
    /// `EventSuggestionGenerator` against the loaded event; the resulting
    /// string lands in `liveSuggestion` and the view re-renders. No-op
    /// when no generator was injected (preview / unit-test path).
    func refreshAISuggestion() async {
        guard let event, let generator = suggestionGenerator else { return }
        let produced = await generator.generate(for: event)
        if let produced, !produced.isEmpty {
            liveSuggestion = produced
        }
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
