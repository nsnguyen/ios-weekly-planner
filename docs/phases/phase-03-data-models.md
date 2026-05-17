# Phase 03 — Data Models & SwiftData Persistence

## Goal
Define the canonical Swift data types (`Event`, `Task`, `InboxSuggestion`, `AIInsight`, `Streak`, `Settings`) and their SwiftData schema. Implement the in-app stores (repositories) — but EventKit and Gmail wiring come in later phases. Seed the demo dataset from `data.jsx` for development and previews.

## Why this is needed
Every screen reads from these models. EventKit (Phase 04) writes through here. Gmail (Phase 18) writes through here. AI (Phase 13) reads from here. We pin the shape first.

## Prerequisites
- Phase 01, 02.

## Files Created / Modified

```
WeeklyPlanner/Models/Event.swift                          # NEW — @Model
WeeklyPlanner/Models/TaskItem.swift                       # NEW — @Model (named TaskItem to avoid Swift.Task collision)
WeeklyPlanner/Models/InboxSuggestion.swift                # NEW — @Model
WeeklyPlanner/Models/AIInsight.swift                      # NEW — @Model (sticky-note text per day)
WeeklyPlanner/Models/Streak.swift                         # NEW — @Model
WeeklyPlanner/Models/Category.swift                       # NEW — enum (raw String) mirroring CategoryPalette keys
WeeklyPlanner/Models/EventSource.swift                    # NEW — enum: manual | gmail | googleCalendar | appleMail
WeeklyPlanner/Models/Priority.swift                       # NEW — enum: low | med | high
WeeklyPlanner/Models/Reminder.swift                       # NEW — struct (timeBefore | locationArrive)
WeeklyPlanner/Models/UserSettings.swift                   # NEW — @Model (singleton)
WeeklyPlanner/Models/WeekDay.swift                        # NEW — value type for a calendar day cell
WeeklyPlanner/Stores/SwiftDataStack.swift                 # NEW — ModelContainer setup
WeeklyPlanner/Stores/EventStore.swift                     # NEW — protocol + SwiftData impl
WeeklyPlanner/Stores/TaskStore.swift                      # NEW
WeeklyPlanner/Stores/InboxStore.swift                     # NEW
WeeklyPlanner/Stores/SettingsStore.swift                  # NEW
WeeklyPlanner/Stores/WeekMath.swift                       # NEW — week helpers (offset, range, weekday)
WeeklyPlanner/Resources/SeedData/seed-week-0.json         # NEW — current week from data.jsx
WeeklyPlanner/Resources/SeedData/seed-week--1.json        # NEW
WeeklyPlanner/Resources/SeedData/seed-week-1.json         # NEW
WeeklyPlanner/Resources/SeedData/seed-week-2.json         # NEW
WeeklyPlanner/Resources/SeedData/seed-tasks.json          # NEW
WeeklyPlanner/Resources/SeedData/seed-inbox.json          # NEW
WeeklyPlanner/Resources/SeedData/seed-insights.json       # NEW (AI sticky note text per day)
WeeklyPlannerTests/Models/EventTests.swift                # NEW
WeeklyPlannerTests/Models/TaskItemTests.swift             # NEW
WeeklyPlannerTests/Stores/EventStoreTests.swift           # NEW
WeeklyPlannerTests/Stores/WeekMathTests.swift             # NEW
WeeklyPlannerTests/Stores/SettingsStoreTests.swift        # NEW
```

## Visual & Interaction Checklist

No UI in this phase. Preview-only fixtures (used by SwiftUI Previews in later phases) live in `WeeklyPlannerTests/Fixtures/`.

## Logic & Data Checklist

### `Event` model

`@Model final class Event`:
- [ ] `id: UUID` (primary key)
- [ ] `eventKitIdentifier: String?` — EventKit `EKEvent.eventIdentifier` once synced.
- [ ] `title: String`
- [ ] `start: Date`
- [ ] `end: Date`
- [ ] `location: String?`
- [ ] `category: Category` (raw `String` storage)
- [ ] `attendeesCount: Int` (default 0)
- [ ] `travelMinutes: Int?` — pre-calculated travel time in minutes.
- [ ] `source: EventSource` (default `.manual`)
- [ ] `gmailMessageID: String?` — link back to the inbox message (Phase 18).
- [ ] `gmailFrom: String?`
- [ ] `gmailSubject: String?`
- [ ] `reminders: [Reminder]` (stored as JSON-encoded blob, decoded on access)
- [ ] `createdAt: Date`, `updatedAt: Date`
- [ ] Computed: `durationHours: Double` → `(end - start) / 3600`.
- [ ] Computed: `weekdayIndex(in calendar:) -> Int` → 0=Mon..6=Sun. Monday-based.
- [ ] Computed: `inkColor(theme:) -> Color` — delegates to `CategoryPalette`.

### `TaskItem` model

`@Model final class TaskItem`:
- [ ] `id: UUID`
- [ ] `eventKitReminderID: String?` — `EKReminder.calendarItemIdentifier` when synced to Reminders.app.
- [ ] `title: String`
- [ ] `due: Date` (date-only; time component optional via `reminderTime`)
- [ ] `done: Bool` (default false)
- [ ] `priority: Priority`
- [ ] `category: Category`
- [ ] `reminderText: String?` — free-form reminder hint, e.g., `"When I arrive at Marina"`.
- [ ] `reminderTime: Date?` — exact alarm time if user picked one.
- [ ] `locationReminder: LocationReminder?` (struct with name + lat/lon + radius).
- [ ] Computed: `weekOffset(from base: Date) -> Int`.

### `InboxSuggestion` model

`@Model final class InboxSuggestion`:
- [ ] `id: UUID`
- [ ] `gmailMessageID: String` (unique)
- [ ] `proposedStart: Date`
- [ ] `proposedEnd: Date?`
- [ ] `title: String`
- [ ] `fromName: String`, `fromEmail: String`
- [ ] `category: Category` (best guess from AI)
- [ ] `subject: String`
- [ ] `bodySnippet: String?` (first 280 chars; full body fetched on demand)
- [ ] `status: InboxStatus` — `.pending | .accepted | .dismissed`
- [ ] `createdAt: Date`

### `AIInsight` model (per-day sticky-note text)

`@Model final class AIInsight`:
- [ ] `id: UUID`
- [ ] `dayKey: String` — `"<weekOffset>:<dayIdx>"` e.g., `"0:5"`.
- [ ] `dateGenerated: Date`
- [ ] `text: String`
- [ ] `colorHex: String` — sticky paper color (yellow `#FFE680`, green `#C9F0E0`, pink `#FFCCC9`).
- [ ] `tiltDegrees: Double` — ±3°..±5°.
- [ ] `dismissed: Bool` (default false).
- [ ] Computed: `theme(_ theme: PaperTheme) -> ...` not needed (color is intrinsic).

### `Streak` model

`@Model final class Streak`:
- [ ] `id: UUID`
- [ ] `name: String` (e.g., `"Morning run"`)
- [ ] `emoji: String` (e.g., `"🏃"`)
- [ ] `consecutiveWeeks: Int`
- [ ] `last7Days: [Bool]` — Mon..Sun.
- [ ] `categoryHint: Category?`

### `Category` enum (raw String)
- [ ] `.work`, `.personal`, `.health`, `.family`, `.focus`, `.travel`.

### `EventSource` enum
- [ ] `.manual`, `.gmail`, `.googleCalendar`, `.appleMail`.

### `Priority` enum
- [ ] `.low`, `.med`, `.high`.

### `Reminder` struct
- [ ] `case timeBefore(minutes: Int)` — `5 | 15 | 30 | 60` typical, but any positive Int.
- [ ] `case onArrive(LocationReminder)` — geofenced.
- [ ] Codable, Equatable, Hashable.

### `LocationReminder` struct
- [ ] `name: String`, `latitude: Double`, `longitude: Double`, `radiusMeters: Double`.

### `UserSettings` (singleton `@Model`)

- [ ] `themeKey: String` (default `"cream"`)
- [ ] `fontKey: String` (default `"caveat"`)
- [ ] `sizeKey: String` (default `"m"`)
- [ ] `weekStartsOnMonday: Bool` (default `true`)
- [ ] `defaultReminderMinutes: Int?` — `nil | 5 | 15 | 30 | 60`. Default `15`.
- [ ] `appleIntelligenceEnabled: Bool` (default `true`).
- [ ] `gmailConnected: Bool` (default `false`).
- [ ] `gmailAccountEmail: String?`
- [ ] `googleCalendarConnected: Bool` (default `false`).
- [ ] `appleMailConnected: Bool` (default `true`).
- [ ] `style: AppStyle` — `.paper | .modern` (default `.paper`).
- [ ] `accentHex: String` — default `#0A84FF`.
- [ ] `modernView: ModernView` — `.day | .twoDay | .week`.
- [ ] `paperView: PaperView` — `.day | .week`.
- [ ] Helper accessors that return `PaperThemeKey`, `PaperFont`, `PaperSize` enums.

### `WeekDay` value type
- [ ] `idx: Int` (0..6 Monday-based)
- [ ] `offset: Int` (week offset relative to today's week)
- [ ] `date: Date`
- [ ] `weekdayShort: String` (`"Mon"`)
- [ ] `weekdayLong: String` (`"Monday"`)
- [ ] `weekdayInitial: String` (`"M"`)
- [ ] `dayNumber: Int`, `monthShort: String`, `year: Int`.

### `WeekMath` (`enum` namespace)
- [ ] `func weekDays(forOffset: Int, calendar: Calendar, today: Date) -> [WeekDay]` — returns 7 days, Monday-first.
- [ ] `func weekMeta(forOffset: Int, today: Date, calendar:) -> WeekMeta` — `{ offset, weekNumber, range "May 11 – 17", monthFull "May 2026", isCurrent }`.
- [ ] Range string formatting: same-month → `"May 11 – 17"`, cross-month → `"May 30 – Jun 5"`.
- [ ] ISO-week numbering using `Calendar.weekOfYear`.
- [ ] All math respects `weekStartsOnMonday` from settings.
- [ ] `func todayIndex(in week: [WeekDay], for today: Date) -> Int?` — used to highlight today.

### `SwiftDataStack`
- [ ] `ModelContainer` registered with schema of all `@Model` classes.
- [ ] Migration policy: lightweight (we'll evolve as we go; document any breaking changes in CHANGELOG).
- [ ] Provides `inMemoryContainer()` factory for tests and previews.
- [ ] Singleton accessor on app launch.

### Stores (repositories)
- [ ] `protocol EventStoring`: `events(forWeekOffset:) async -> [Event]`, `event(id:) async -> Event?`, `upsert(_ event:) async throws`, `delete(id:) async throws`, `observe(weekOffset:) -> AsyncStream<[Event]>`.
- [ ] `protocol TaskStoring`: same shape with `tasks(forWeekOffset:)`, `toggle(id:)`, `upsert/delete`.
- [ ] `protocol InboxStoring`: `pending(forWeekOffset:)`, `accept(id:)`, `dismiss(id:)`.
- [ ] `protocol SettingsStoring`: `current() -> UserSettings`, `update(_:) async throws`, `publisher() -> AsyncStream<UserSettings>`.
- [ ] SwiftData-backed concrete impls. Inject via `@Environment(\.eventStore)` etc.
- [ ] For tests, in-memory impls.

### Seed data
- [ ] Convert every entry from `docs/mock/data.jsx` (EVENTS, TASKS, INBOX_SUGGESTIONS, AI sticky notes from `paper-planner.jsx` `insights` dict) into JSON files.
- [ ] Reference date is **Saturday, May 16, 2026**, week-offset 0 = Mon May 11.
- [ ] In `#if DEBUG` builds, on first launch, populate the container from seed JSONs if empty.
- [ ] Production builds **do not** seed (start empty, user adds events or imports).
- [ ] Document the seed-loading flag clearly.

## Tests (TDD)

`EventTests`
- [ ] `testEventDurationHours()` — start 9.0, end 10.5 → 1.5.
- [ ] `testEventInkColorWork()` — work category, cream theme → `#1A3A7A`.
- [ ] `testEventEncodingRoundTrip()` — Codable round-trip preserves all fields.

`TaskItemTests`
- [ ] `testPriorityOrdering()` — high > med > low when sorting.
- [ ] `testReminderTextDefaultsToNil()`.

`EventStoreTests` (in-memory SwiftData)
- [ ] `testUpsertNewEvent()`.
- [ ] `testUpdateExistingEventByID()`.
- [ ] `testFetchByWeekOffset()` — events with start within week range.
- [ ] `testObserveEmitsOnInsert()`.

`WeekMathTests`
- [ ] `testWeekDaysOffsetZeroOnMay16_2026_ReturnsMay11ThroughMay17()`.
- [ ] `testWeekDaysOffsetMinusOneReturnsMay4ThroughMay10()`.
- [ ] `testCrossMonthRangeString()` — week of May 30 → `"May 30 – Jun 5"`.
- [ ] `testWeekStartsOnSundayShiftsDays()`.
- [ ] `testTodayIndexInCurrentWeekIs5OnMay16_2026()`.

`SettingsStoreTests`
- [ ] `testDefaultsMatchSpec()`.
- [ ] `testUpdatePersistsAcrossNewContainer()`.

## Acceptance Criteria
- All models compile under Swift 6 strict concurrency.
- All tests green.
- Seed data loads in DEBUG. Previews work using `.inMemoryContainer()`.
- `EventStoring` etc. have no EventKit references (Phase 04 adds them via a different implementation/decorator).

## Out of Scope
- EventKit bridging (Phase 04).
- Gmail-sourced data (Phase 18).
- Foundation Models tool calls reading these (Phase 13).
- iCloud / CloudKit sync.

## Risks & Notes
- **Swift's `Task` collides** with our task model — name ours `TaskItem`.
- **SwiftData & Swift 6 concurrency** — `ModelContext` is not `Sendable`. Use `@MainActor` model context and `ModelActor` for background work.
- **EventKit mapping** — keep the EventKit-specific fields (`eventKitIdentifier`, etc.) nullable on `Event` so manual events without EventKit links still work in Phase 03.
- **Date storage** — store all dates in UTC; format using `Calendar.current` at display time.
