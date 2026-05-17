# Phase 04 — EventKit & Calendar Integration

## Goal
Wire `Event` and `TaskItem` to EventKit so the app reads and writes the user's iOS Calendar and Reminders. Permission flow, two-way sync, conflict resolution, and category mapping all land here.

## Why this is needed
The user wants production-ready and App Store-worthy. EventKit is the canonical iOS calendar store — events created in our app must show up in Calendar.app and vice versa. Apple actively rejects calendar apps that don't sync.

## Prerequisites
- Phase 01 (entitlements + Info.plist usage strings).
- Phase 03 (models + stores).

## Files Created / Modified

```
WeeklyPlanner/Stores/EventKit/EventKitGateway.swift          # NEW — protocol facade over EKEventStore
WeeklyPlanner/Stores/EventKit/EventKitAuthorization.swift    # NEW — permission flow + status
WeeklyPlanner/Stores/EventKit/EventKitSync.swift             # NEW — sync engine (push, pull, reconcile)
WeeklyPlanner/Stores/EventKit/EKEvent+Mapping.swift          # NEW — EKEvent ↔ Event
WeeklyPlanner/Stores/EventKit/EKReminder+Mapping.swift       # NEW — EKReminder ↔ TaskItem
WeeklyPlanner/Stores/EventKit/CategoryCalendarManager.swift  # NEW — ensures per-category EKCalendars exist
WeeklyPlanner/Stores/EventStore+EventKit.swift               # NEW — decorator that mirrors writes to EventKit
WeeklyPlanner/Stores/TaskStore+EventKit.swift                # NEW — decorator
WeeklyPlanner/Features/Permissions/PermissionPrompts.swift   # NEW — first-run prompt UI shell (used in Phase 16/17)
WeeklyPlannerTests/EventKit/EventKitGatewayTests.swift       # NEW
WeeklyPlannerTests/EventKit/EventKitSyncTests.swift          # NEW
WeeklyPlannerTests/EventKit/EKEventMappingTests.swift        # NEW
```

## Visual & Interaction Checklist

No standalone screen. The only UI in this phase is the system permission alert + a fallback explanation sheet when permission is denied:

- [ ] System permission alert triggered by `EKEventStore.requestFullAccessToEvents(completion:)` — uses `NSCalendarsFullAccessUsageDescription` string from Info.plist.
- [ ] Same for Reminders: `requestFullAccessToReminders(completion:)`.
- [ ] If user denies, store the state; later phases show an in-app card with an "Open Settings" button (deep-link via `UIApplication.openSettingsURLString`).
- [ ] Phase 16 (Settings) will show calendar/reminders status rows; this phase just ensures the wire is ready.

## Logic & Data Checklist

### `EventKitGateway` (protocol + impl)
- [ ] Wraps `EKEventStore` — single shared instance.
- [ ] `requestEventsAccess() async -> EKAuthorizationStatus`.
- [ ] `requestRemindersAccess() async -> EKAuthorizationStatus`.
- [ ] `eventsAccessStatus: EKAuthorizationStatus` (observable).
- [ ] `remindersAccessStatus: EKAuthorizationStatus`.
- [ ] `fetchEvents(startDate:endDate:calendars:) async throws -> [EKEvent]`.
- [ ] `fetchReminders(in:) async throws -> [EKReminder]`.
- [ ] `save(_ ekEvent: EKEvent) throws`, `remove(_ ekEvent: EKEvent) throws`.
- [ ] `save(_ ekReminder: EKReminder) throws`, `remove(_ ekReminder: EKReminder) throws`.
- [ ] Listen for `EKEventStoreChangedNotification` and publish change events.

### `CategoryCalendarManager`
- [ ] On first run after permission granted, create six `EKCalendar`s named "Planner — Work", "Planner — Personal", etc., with the corresponding colors (`CategoryPalette.dot`).
- [ ] Calendars live in the default `EKSource` (iCloud if available, else local).
- [ ] Persist a `[Category: String]` map (calendar identifier → category) in `UserSettings`.
- [ ] If a user later deletes one of these calendars manually, detect on next sync and recreate.
- [ ] Importing existing events with no category match uses the user's default calendar (assigned to `.personal` by default; user can re-categorize from Event Detail in Phase 11).

### `EKEvent ↔ Event` mapping
- [ ] Outbound (`Event → EKEvent`): set `title`, `startDate`, `endDate`, `location`, `calendar` (per category), `notes` (encode our `gmailMessageID`/`source` as a JSON suffix `--planner-meta:{...}--` so we round-trip after external edits).
- [ ] `attendees` field is read-only from EventKit; we don't write attendees (system doesn't allow setting them programmatically). Show `attendeesCount` from EventKit when reading.
- [ ] Inbound (`EKEvent → Event`): parse `notes` for `--planner-meta:{...}--` and restore custom fields; if absent, default `source = .manual`.
- [ ] `alarms` ↔ `reminders` (`Reminder.timeBefore` ↔ `EKAlarm.relativeOffset` in seconds).
- [ ] Geofenced alarms (`Reminder.onArrive`) ↔ `EKAlarm(structuredLocation:)` with `proximity = .enter`, radius from `LocationReminder.radiusMeters`.
- [ ] Recurrence: **NOT supported in v1.0** — flag any incoming recurring event with a non-editable indicator (deferred to v1.1).

### `EKReminder ↔ TaskItem` mapping
- [ ] Outbound: `title`, `dueDateComponents` from `due`, `priority` (0=none, 1=high, 5=med, 9=low), `notes` for `category` and `reminderText`.
- [ ] Inbound: reverse; default category `.personal` if not encoded.
- [ ] Completion mirrors `EKReminder.isCompleted`.

### `EventKitSync` (engine)
- [ ] On launch (post-permission), fetch all events in `[today - 8 weeks, today + 16 weeks]`. Reconcile with SwiftData:
  - **Match** by `eventKitIdentifier` if set on our side.
  - For EKEvents missing from our store, insert them (default category `.personal`).
  - For our events missing from EventKit, push them out (creating in the per-category calendar).
- [ ] Same logic for Reminders.
- [ ] Listen to `EKEventStoreChangedNotification` → trigger incremental sync.
- [ ] Conflict resolution: **last-write-wins by `updatedAt`** (EKEvent's `lastModifiedDate` vs. our `updatedAt`).
- [ ] Sync runs on a background `ModelActor`; updates SwiftData on `@MainActor`.
- [ ] Expose `syncState: SyncState` (idle | running | failed(Error)) — Settings displays this in Phase 17.

### Decorators
- [ ] `EventStore+EventKit` wraps the base SwiftData `EventStore`. On `upsert(event)`, also push to EventKit. On `delete`, remove from EventKit. On observed changes from EventKit, refresh SwiftData.
- [ ] Same pattern for tasks/reminders.

### Permission flow integration
- [ ] On first app launch (post Phase 06), show the day page in a "preview" state (read-only seed data). Pressing the AI button or add-event button triggers the permission flow.
- [ ] Permission denied UX: explanation card with "Open Settings" deep link. Documented; UI shipped in Phase 16.

## Tests (TDD)

`EventKitGatewayTests` (use `EKEventStore` mock subclass; no real device required for unit tests)
- [ ] `testRequestEventsAccessReturnsStatus()`.
- [ ] `testFetchEventsInRangeFiltersOutOfRange()`.
- [ ] `testSaveEventPersistsCalendarAssignment()`.

`EKEventMappingTests`
- [ ] `testOutboundMappingPreservesAllCoreFields()`.
- [ ] `testNotesEncodeRoundTrip()` — gmail meta is preserved through a round trip.
- [ ] `testAlarmRelativeOffsetMatchesReminderMinutes()`.
- [ ] `testGeofencedAlarmMapsToStructuredLocation()`.

`EventKitSyncTests`
- [ ] `testInitialSyncImportsExternalEvent()`.
- [ ] `testInitialSyncPushesLocalEvent()`.
- [ ] `testConflictResolutionPrefersNewerUpdatedAt()`.
- [ ] `testEKChangeNotificationTriggersIncrementalSync()`.

## Acceptance Criteria
- Requesting permissions works on a real device (iOS 26).
- Adding an event in the app shows up in Apple Calendar within 2 seconds.
- Editing an event in Apple Calendar shows up in our app within 2 seconds.
- Toggling a task in our app shows up as completed in Reminders.app.
- Six per-category calendars exist after first permission grant.
- All tests green (with EKEventStore mocked).

## Out of Scope
- Recurring events (v1.1 — explicitly noted in Acceptance for v1.0).
- Sharing / inviting (Phase 11 shows attendees read-only).
- Background fetch beyond `EKEventStoreChangedNotification` push (acceptable for v1.0).
- iCloud-only edge cases (handled implicitly by EventKit).

## Risks & Notes
- **Permission denial blocks every screen.** Build the read-only seed-data fallback so the app is still demoable without permissions in Phase 06.
- **`EKEvent.notes` is user-visible.** The `--planner-meta:{...}--` suffix will appear in Apple Calendar's event details. Keep it short. Alternative: use `EKEvent.structuredLocation.geoLocation` + a custom URL scheme — but `notes` is the simplest reliable channel.
- **Calendar app shows our color via `EKCalendar.cgColor`.** Match the category dot color exactly.
- **Apple Reminders' `priority` mapping** is non-obvious: EKReminder priority is 0 (none), 1 (high), 5 (medium), 9 (low). Document.
- **No `EKEventStore` mocks in iOS SDK** — write our own `EKEventStoreProtocol` and a fake for tests.
