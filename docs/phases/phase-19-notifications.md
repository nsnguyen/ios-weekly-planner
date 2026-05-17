# Phase 19 — Notifications (Time + Location Reminders)

## Goal
Wire the time-based and location-based reminders defined on events and tasks into real iOS local notifications via `UNUserNotificationCenter` and `CLRegion`. Apply the user's default-reminder preference; allow per-event override. Handle permission, denied state, and silent re-scheduling on event edits.

## Why this is needed
Mock toggles for "Alert me" and "When I arrive" must result in actual phone buzzes. App Store reviewers will test this.

## Prerequisites
- Phases 03 (`Reminder`, `LocationReminder`), 04 (EventKit alarms), 11 (event sheet toggles), 16 (default reminder pref).

## Files Created / Modified

```
WeeklyPlanner/Notifications/NotificationCenter.swift              # NEW — typed wrapper
WeeklyPlanner/Notifications/NotificationAuthorization.swift       # NEW — request + status
WeeklyPlanner/Notifications/EventNotificationScheduler.swift      # NEW — schedules per Event
WeeklyPlanner/Notifications/TaskNotificationScheduler.swift       # NEW — schedules per Task
WeeklyPlanner/Notifications/LocationReminderManager.swift         # NEW — CLLocationManager + monitoring
WeeklyPlanner/Notifications/NotificationContentBuilder.swift      # NEW — title/body localized
WeeklyPlanner/Notifications/NotificationCategoryIDs.swift         # NEW — actionable categories
WeeklyPlanner/Notifications/AppDelegate+Notifications.swift       # NEW — receive + route
WeeklyPlanner/App/WeeklyPlannerApp.swift                          # MODIFY — register delegate
WeeklyPlannerTests/Notifications/EventNotificationSchedulerTests.swift  # NEW
WeeklyPlannerTests/Notifications/LocationReminderManagerTests.swift     # NEW
WeeklyPlannerTests/Notifications/NotificationContentBuilderTests.swift  # NEW
```

## Visual & Interaction Checklist

- [ ] On first event that has reminders, system permission alert for Notifications fires once. Uses standard iOS prompt — no custom UI needed.
- [ ] If notifications denied, Settings shows a banner in Connections section: `"Notifications are off — reminders won't fire. Open Settings to enable."` with deep-link button.
- [ ] Permission for Location (When-In-Use) prompted only when user first toggles "When I arrive" on the event sheet (Phase 11 calls into this phase's manager).
- [ ] Notifications display:
  - **Title**: event title (e.g., `"Lunch with Sara"`).
  - **Subtitle**: time + location (e.g., `"1:00 PM · Café Bleu"`).
  - **Body**: short hint (`"In 15 minutes."` for time-based, `"You've arrived at the location."` for location-based).
  - **Sound**: `.default`.
- [ ] Tapping the notification opens the app to the event detail sheet for that event.
- [ ] Notification actions:
  - `"Snooze 10 min"` (re-schedule, dismiss).
  - `"View"` (open app + sheet).
  - `"Mark Done"` (only for tasks; toggles `done` and removes notification).

## Logic & Data Checklist

### `NotificationAuthorization`
- [ ] `request() async -> UNAuthorizationStatus` — requests `[.alert, .sound, .badge]` and `.timeSensitive` interruption level (declared via `com.apple.developer.usernotifications.communication` entitlement — Phase 01).
- [ ] `status() async -> UNAuthorizationStatus`.

### `EventNotificationScheduler`
- [ ] `schedule(event:)`:
  - Clears existing notifications for `event.id`.
  - For each `Reminder.timeBefore(minutes:)`: build a `UNCalendarNotificationTrigger` at `event.start - minutes`.
  - For each `Reminder.onArrive(location:)`: register a `CLCircularRegion` and schedule a `UNLocationNotificationTrigger` (notifyOnEntry=true, notifyOnExit=false).
  - Use stable `requestIdentifier`s: `"event-{id}-time-{minutes}"`, `"event-{id}-arrive"`.
- [ ] `cancel(eventID:)`: removes all pending requests with matching prefix.
- [ ] `rescheduleAll()`: bulk re-build (used after permission grant or settings change).

### `TaskNotificationScheduler`
- [ ] Similar shape for `TaskItem.reminderTime` (calendar trigger at the exact `reminderTime` if set).
- [ ] Location-based task reminders supported (matches `data.jsx` task `t3` "When I arrive at Marina").

### `LocationReminderManager`
- [ ] Holds the shared `CLLocationManager`.
- [ ] Tracks up to 20 active regions (iOS hard limit). Priority: today's & next 24h events first.
- [ ] On region entry → `UNNotificationRequest` fires the location notification.
- [ ] Permission flow: `requestWhenInUseAuthorization` first; if user toggles a far-future event with location alert, request `requestAlwaysAuthorization` (better reliability when app is killed). Soft ask: explanation card before the system prompt.

### `NotificationContentBuilder`
- [ ] Localized strings via `String(localized:)` (Phase 21 will translate).
- [ ] Truncates titles > 64 chars.

### `NotificationCategoryIDs`
- [ ] `eventCategory` with actions: `viewEvent`, `snooze10`.
- [ ] `taskCategory` with actions: `viewTask`, `markDone`.

### App delegate routing
- [ ] On launch with notification payload, parse `event.id` or `task.id` from `userInfo`. Open the app to the matching sheet.
- [ ] `userNotificationCenter(_:didReceive:withCompletionHandler:)` handles actions:
  - `viewEvent`/`viewTask` → open detail.
  - `snooze10` → schedule a new request 10 minutes from now with the same content.
  - `markDone` → `TaskStore.toggle(id:)`.

### Default reminder application
- [ ] When a new `Event` is created (via Inbox accept in Phase 18, or future manual add), `Reminder.timeBefore(minutes: settings.defaultReminderMinutes ?? 15)` is added — unless the user has opted out (`None`).
- [ ] Existing events left unchanged when user changes default reminder.

### Re-scheduling triggers
- [ ] After any `Event` save → reschedule that event's notifications.
- [ ] After permission grant → call `rescheduleAll()` for events in next 30 days.
- [ ] After event delete → cancel notifications.

## Tests (TDD)

`EventNotificationSchedulerTests` (using `UNUserNotificationCenter` mock)
- [ ] `testScheduleTimeReminderProducesRequest()`.
- [ ] `testReschedulingClearsOldRequests()`.
- [ ] `testCancelByEventIDRemovesAllRequests()`.

`LocationReminderManagerTests`
- [ ] `testRegisterUpTo20Regions()`.
- [ ] `testPriorityKeepsTodayEventsActive()`.
- [ ] `testEntryFiresNotification()`.

`NotificationContentBuilderTests`
- [ ] `testTitleTruncated()`.
- [ ] `testTimeBasedBodyText()`.
- [ ] `testLocationBasedBodyText()`.

## Acceptance Criteria
- Creating an event with a 15-minute reminder fires a real notification 15 minutes before start time on a physical device.
- Toggling location alert on Sara's birthday fires when the device enters the Trick Dog geofence (verified manually with simulator location override).
- Snooze 10 button re-schedules without losing actions.
- Tap notification → app opens to event sheet.
- Permission deny path shows the in-Settings banner; granting later resumes scheduling.

## Out of Scope
- Rich notifications with images.
- Apple Watch notification handoff (works out-of-the-box via mirror; no extra code).
- Sound customization (default).
- "Snooze for 1 hour" or smart-snooze (defer v1.1).

## Risks & Notes
- **iOS 20-region geofence limit** is per-app. We may exceed it if user has many location-tagged events. Build a priority queue keyed by proximity-in-time.
- **`UNAuthorizationOptions.timeSensitive`** requires the entitlement set in Phase 01. Without it, reminders may be deferred during Focus.
- **Background launches**: location entry can wake the app in background. Keep `application(_:didFinishLaunchingWithOptions:)` lightweight.
- **App Store review**: reviewer will likely test "When I arrive" — provide notes referencing simulator location override in App Store Connect.
- **Notification settings drift**: user can mute individual notifications in iOS Settings; we can't detect that. Document.
