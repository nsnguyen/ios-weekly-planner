# Milestone J — Functional Completeness (Phases 22, 23, 24)

> **Status:** Spec — approved 2026-05-22. Branch: `milestone-j-completeness`.
> Successor to Milestone I (Phase 21, Accessibility) and predecessor to
> the renamed Milestone K (Ship — Phases 25 + 26, formerly 22 + 23).

## Why this milestone exists

The Paper app shipped Milestones A–I as a beautiful, accessible read-only
shell over EventKit + Gmail + Foundation Models. Three functional gaps
remain that v1.0 cannot ship without:

1. **The AI sticky note is one-shot.** `StickyInsightGenerator` runs once
   per `(weekOffset, dayIdx)` and freezes. It produces a single encouraging
   line — not the contextual "Leave by 9:35 for dentist" / "Don't forget
   Sara's gift!" nudges the mock promised.
2. **Events are read/sync-only.** Inbox suggestions and EventKit sync
   populate events, but the user can't create one manually. `PaperEventSheet`
   only edits alert toggles and supports delete.
3. **Tasks are toggle-only.** `TodoBlock` lets the user check off seeded
   tasks. No add, no edit, no delete.

This milestone closes those three gaps before the Ship milestone.

## Scope

Three independent phases, executed in order on `milestone-j-completeness`.
Each phase is one mergeable PR and produces a runnable app.

| Phase | Title                                  | Branch on `milestone-j-completeness` |
|-------|----------------------------------------|--------------------------------------|
| 22    | Manual Event CRUD                      | direct                               |
| 23    | Manual Task CRUD                       | direct                               |
| 24    | AI Sticky v2 — Live & Actionable       | direct                               |

Phases 22 + 23 share the "compose-edit-delete on torn paper" pattern;
Phase 23 deliberately follows 22 so the inline-vs-sheet decisions stay
consistent.

After Phase 24, the milestone branch merges to `main`. The two existing
ship phases (formerly 22 + 23) renumber to **25** (Final Polish, App Icon,
Launch Screen, Privacy) and **26** (App Store Submission & TestFlight)
and form the renamed **Milestone K — Ship**.

---

## Phase 22 — Manual Event CRUD

### Goal

Let the user create new events on the Day page via a floating ink "+"
button, and edit existing events' title / start / end / category /
location through the same `PaperEventSheet`. Save round-trips through
`EventKitMirroringEventStore` so changes land in real iOS Calendar.

### Architecture

#### Data flow

```
                        +-------------------+
                        | FloatingInkButton |   tap "+"
                        +---------+---------+
                                  |
                                  v
+----------------+        +-------+--------+         +------------+
| PaperEventSheet| <----- | EventComposer  | ------> | EventStore |
|  (mode: .edit  |  bind  |     State      |  save   |  .upsert   |
|  or .create)   | ----->                  |         +------------+
+----------------+        +----------------+               |
                                                           v
                                                +----------+---------+
                                                | EventKitMirroring  |
                                                |    (already wired) |
                                                +--------------------+
```

#### Mode state machine

`PaperEventSheet` gets `mode: SheetMode`:
- `.view` — current behavior. Title/time are read-only handwriting; only
  alert toggles + delete are interactive.
- `.edit` — title/time/category/location become editable. "Save" + "Cancel"
  pinned at the top-trailing in place of the close X. Discard-confirm on
  Cancel when the composer is dirty.
- `.create` — same as `.edit` but the composer starts empty and the
  Delete button is hidden.

#### `EventComposerState` (`@Observable`)

```swift
@MainActor @Observable
final class EventComposerState {
    var title: String
    var start: Date
    var end: Date
    var category: Category
    var location: String
    var alertOn: Bool
    var alertMinutes: Int
    var locationAlertOn: Bool

    var titleIsValid: Bool { !title.trimmed.isEmpty }
    var timesAreValid: Bool { end > start }
    var canSave: Bool { titleIsValid && timesAreValid }

    static func empty(at date: Date, calendar: Calendar) -> EventComposerState
    static func from(_ event: Event) -> EventComposerState
    func build(id: UUID = UUID()) -> Event
}
```

#### Defaults for "+"

- `start = nextHour(currentDayPageDate)` — e.g., tap at 3:42 pm → start at 4:00 pm.
- `end = start + 1h`.
- `category = .personal`.
- `alertOn = false` (matches existing default-reminder respect from `DefaultReminderPolicy`).
- `location = ""`.

#### Validation + save

- Save button is disabled when `!canSave`.
- Title field renders a faint red wavy underline (handwriting style) when empty.
- Times invalid → end-time picker text turns `theme.redInk`.
- Save → `eventStore.upsert(state.build())` → `EventStore` posts
  `.eventStoreDidChange` → notification reschedules + EventKit mirror sync
  for free.

### New atoms

- **`InkTextField`** — `TextField` wrapped in handwriting font/size,
  caret colored `theme.blueInk`, no border (paper-feel). Placeholder is
  italicized in `theme.ink2`.
- **`PaperDateTimeRow`** — leading handwriting label ("Starts" / "Ends"),
  trailing `DatePicker(.compact)` styled to render its date+time chips in
  handwriting font via `.environment(\.font, font.font(at: 17 * size.scale))`.
- **`CategorySwatchRow`** — `HStack` of 4 ink dots (personal/work/health/family
  colors from `PaperTheme.inkColors`). Selected swatch gets a hand-drawn ring
  overlay (existing `WavyUnderline` adapted to a circle, deferred to a tiny
  new `CircularDoodle` if `WavyUnderline` doesn't fit cleanly).
- **`LocationField`** — `InkTextField` with a tiny location pin glyph
  (SF Symbol `mappin.circle`) on the leading edge, rendered in `theme.ink3`.

### `FloatingInkButton`

- 56×56 circle, ink-stroke ring + "+" glyph rendered as a SwiftUI `Canvas`
  drawing two perpendicular ink strokes (uses the same `InkStroke`
  primitive as `WavyUnderline`).
- Position: anchored bottom-trailing, offset 24pt from trailing edge,
  20pt above tab bar height (uses `Spacing.tabBarHeight`).
- Hides when any sheet is open (`isAnySheetOpen` env binding from `AppShell`).
- Respects safe area + keyboard via `.safeAreaPadding`.
- Mounted at `AppShell` level so Day and Week pages both surface it
  (Week page's "+" defaults `start = noon of focused day`).
- Long-press → context menu: "New event", "New task" (Phase 23 wires
  the second action).
- Accessibility: label `"Add event"`, hint `"Opens new event composer"`,
  trait `.isButton`. Identifier `appshell.fab.add`.

### Files

```
WeeklyPlanner/Features/EventDetail/EventComposerState.swift          # NEW
WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift        # NEW (mode .edit/.create branch)
WeeklyPlanner/Features/EventDetail/EditableFields/InkTextField.swift # NEW
WeeklyPlanner/Features/EventDetail/EditableFields/PaperDateTimeRow.swift # NEW
WeeklyPlanner/Features/EventDetail/EditableFields/CategorySwatchRow.swift # NEW
WeeklyPlanner/Features/EventDetail/EditableFields/LocationField.swift # NEW
WeeklyPlanner/Features/DayPage/FloatingInkButton.swift               # NEW
WeeklyPlanner/Navigation/AppShell.swift                              # MODIFY (mount FAB + isAnySheetOpen)
WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift             # MODIFY (mode prop, dispatch)
WeeklyPlanner/Features/EventDetail/EventDetailViewModel.swift        # MODIFY (save / cancel methods)
WeeklyPlannerTests/EventDetail/EventComposerStateTests.swift         # NEW
WeeklyPlannerTests/EventDetail/PaperEventSheetEditTests.swift        # NEW
WeeklyPlannerUITests/EventCreateFlowUITests.swift                    # NEW
```

### Tests (TDD)

`EventComposerStateTests`
- `testEmptyDefaults_startNextHour_endPlusOne`
- `testFromEvent_roundTrips`
- `testCanSave_falseWhenTitleEmpty`
- `testCanSave_falseWhenEndBeforeStart`
- `testBuild_setsSourceManual`

`PaperEventSheetEditTests`
- `testCreateMode_saveCallsUpsert`
- `testEditMode_saveUpdatesExistingEvent`
- `testCancelWithDirtyState_promptsConfirm`
- `testTimePickerEdge_endAutoBumpsWhenStartAdvancesPastEnd`

`EventCreateFlowUITests`
- `testCreateEvent_endToEnd` — tap FAB, fill title "Lunch with Jamie",
  pick time, save, assert row appears in Day page event list.

### Acceptance criteria

- Floating "+" appears on Day + Week pages; tap opens an empty `PaperEventSheet`
  in `.create` mode.
- Tap an existing event → sheet opens in `.edit` mode (was `.view`); a small
  pencil ink-glyph in the header indicates editability.
- Saving a new event makes it appear in the same Day page row list within
  one frame (refresh runs on `.eventStoreDidChange`).
- Cancel from a dirty composer prompts "Discard changes?"
- Real iOS Calendar shows the new/edited event (via the existing EventKit
  mirror decorator).
- All `XCUIAccessibilityAudit` UI tests still green; FAB has VoiceOver label.

### Out of scope (deferred to a later phase)

- Recurrence rules.
- Attendees / invitees editing.
- Cross-day events (start/end on different dates).
- Inline-on-page editing (no sheet) — the spec is sheet-only.

### Risks

- **Keyboard occlusion** on smaller devices — `InkTextField` must scroll
  the sheet up. Use `.safeAreaInset(edge: .bottom)` for the keyboard area.
- **`@Observable` + `@Bindable` in SwiftUI 17** — composer state must use
  `@Bindable var state` inside the sheet for two-way bindings to work
  with `TextField` / `DatePicker`. Caught in code review of Phase 16
  (settings used same pattern).
- **EventKit upsert latency** — when the user spams Save quickly, the
  `MainActor`-isolated mirror may queue. Acceptance only requires
  optimistic UI; one-frame guarantee is the SwiftData write, not the
  EventKit roundtrip.

---

## Phase 23 — Manual Task CRUD

### Goal

Let the user add new tasks to a day's `TodoBlock` via an inline "+ add a
task" row, edit priority + due date via a mini paper popover, and delete
via swipe or popover.

### Architecture

#### `TaskComposerState` (`@Observable`)

```swift
@MainActor @Observable
final class TaskComposerState {
    var title: String = ""
    var isComposing: Bool = false
    var priority: Priority = .medium
    var due: Date          // defaults to current Day page's date

    var canCommit: Bool { !title.trimmed.isEmpty }
    func build(forDay: Date) -> TaskItem
    func reset()
}
```

#### TodoBlock extension

Three new view-builders in `TodoBlock`:

1. **`addRow`** — pinned at the bottom of the existing `VStack`. Two
   visual states:
   - Idle: dashed border row, faint "+ add a task" handwriting placeholder,
     ink-gray (`theme.ink3`). Tap → `composer.isComposing = true`.
   - Composing: inline `InkTextField` (reused from Phase 22) with autofocus,
     Return commits, Escape / blur cancels (saves if non-empty, discards
     if empty).

2. **`swipeActions`** on each existing `TodoRow`:
   - Trailing: Delete (ink red destructive).
   - Leading: Toggle priority (cycles low → med → high → low). Visual
     spring on the priority bang glyph.

3. **`contextMenu`** (long-press) on each `TodoRow`:
   - Opens `TaskMiniPopover` anchored to the row.

#### `TaskMiniPopover`

- ~220×180 floating paper card, anchored above the long-pressed row.
- Drop shadow + slight tilt (`-1°`, paper-feel).
- Contents:
  - **Priority row** — `HStack` of 3 ink dots (gray / yellow / red);
    selected gets a hand-drawn ring.
  - **Due row** — three chips (`Today` / `Tomorrow` / `Pick…`). `Pick…`
    opens a compact `DatePicker(.graphical)` in-popover.
  - **Delete** — handwriting "Delete" with red wavy underline.
  - **Done** — handwriting "Done" in blue ink, dismisses popover.

#### Store API surface

- `TaskStoring` gains `func upsert(_ task: TaskItem) async throws`.
- `TaskStoring` gains `func delete(id: UUID) async throws`.
- `SwiftDataTaskStore` implements both; both post `.taskStoreDidChange`
  on mutation (already broadcast by other mutating methods).
- `StubTaskStore` mirrors for previews + tests.
- Notification rescheduling (`NotificationReschedulingObserver` from
  Phase 19) already listens to `.taskStoreDidChange` and clears + re-emits
  by prefix — adds and deletes get scheduled for free.

#### Empty-state evolution

`EmptyDayState` (Phase 06) shown when events + inbox + tasks all empty.
This phase adds an "Add a task" CTA below the empty state's hint text:
tap → opens the `addRow` composer in the embedded `TodoBlock` (which
then renders even though `tasks.isEmpty`).

### Files

```
WeeklyPlanner/Features/DayPage/TaskComposerState.swift          # NEW
WeeklyPlanner/Features/DayPage/TaskMiniPopover.swift            # NEW
WeeklyPlanner/Features/DayPage/TodoBlock.swift                  # MODIFY (addRow, composer)
WeeklyPlanner/Features/DayPage/TodoRow.swift                    # MODIFY (swipeActions, contextMenu)
WeeklyPlanner/Features/DayPage/EmptyDayState.swift              # MODIFY (Add-task CTA)
WeeklyPlanner/Features/DayPage/DayPageViewModel.swift           # MODIFY (addTask / deleteTask / updateTask)
WeeklyPlanner/Stores/TaskStore.swift                            # MODIFY (+upsert, +delete)
WeeklyPlanner/Stores/Environment+Stores.swift                   # MODIFY (Stub conformance)
WeeklyPlannerTests/DayPage/TaskComposerStateTests.swift         # NEW
WeeklyPlannerTests/DayPage/TodoBlockCRUDTests.swift             # NEW
WeeklyPlannerTests/Stores/TaskStoreUpsertDeleteTests.swift      # NEW
WeeklyPlannerUITests/TaskCreateFlowUITests.swift                # NEW
```

### Tests (TDD)

`TaskComposerStateTests`
- `testCanCommit_falseWhenTitleEmpty`
- `testBuild_usesProvidedDay_and_currentPriority`
- `testReset_clearsAll`

`TodoBlockCRUDTests`
- `testAddRowComposes_andReturnCommitsTask`
- `testAddRowEscape_discards`
- `testSwipeDelete_callsStoreDelete`
- `testLongPress_opensMiniPopover_andPriorityChangeCallsUpsert`
- `testMiniPopover_dueChip_Tomorrow_setsDueToNextDay`

`TaskStoreUpsertDeleteTests`
- `testUpsert_newTask_persists_and_postsChange`
- `testUpsert_existingTask_replacesFields`
- `testDelete_removesAndPostsChange`
- `testDelete_unknownID_throwsNotFound`

`TaskCreateFlowUITests`
- `testInlineAddTask_endToEnd` — tap addRow, type "Prep slides", Return,
  assert row appears.

### Acceptance criteria

- Tap the dashed row → inline text field with caret on screen in <300ms.
- Type + Return commits the task; refresh shows it sorted by priority.
- Empty title + Return / blur → no row created (composer resets).
- Swipe left → Delete; tap Delete → row animates out with strikethrough fade.
- Long-press → mini popover opens; changing priority is reflected in the
  bang glyph after dismissing.
- All accessibility audit UI tests still green.

### Out of scope

- Multi-line task notes.
- Recurring tasks.
- Task → event conversion (deferred).
- Drag-to-reorder.

### Risks

- **`@FocusState` + autofocus timing** in SwiftUI 17 can race the
  insertion of the field. Use `.task { focused = true }` not `.onAppear`.
- **Swipe-actions conflict with horizontal page-flip gesture.**
  `HorizontalSwipeGesture` lives at the `PaperSurface` level; trailing
  swipe on a `List.swipeActions` row should consume the horizontal drag
  first. Test on-device — caught a similar pattern in Phase 08.
- **Popover positioning** when the long-pressed row is near the screen
  bottom; flip popover above the row when needed. SwiftUI's built-in
  `.popover` handles this; we render the popover via `.popover()` rather
  than a manual ZStack overlay.

---

## Phase 24 — AI Sticky v2 (Live & Actionable)

### Goal

Replace the single frozen sticky note per day with a cascade of up to 3
context-aware, actionable insights drawn from four signal sources (travel
ETA, weather, calendar keyword detection, inbox-flagged items). Refresh
automatically on day-page open and pull-to-refresh; tap deep-links to
the relevant surface; long-press dismisses or refreshes.

### Architecture

#### Data model migration

`AIInsight` (`Models/AIInsight.swift`) gains three fields. The SwiftData
`@Model` `Schema.Version` advances from V1 → V2 with a lightweight
migration that defaults old rows:

```swift
@Model
final class AIInsight {
    @Attribute(.unique) var id: UUID
    var dayKey: String              // "<weekOffset>:<dayIdx>"
    var dateGenerated: Date
    var text: String
    var colorHex: String
    var tiltDegrees: Double
    var dismissed: Bool

    // NEW in v2:
    var kind: String                // raw value of InsightKind
    var actionURL: String?          // deep link or external URL
    var priority: Int               // cascade sort order (lower = earlier)
}

enum InsightKind: String, Codable {
    case encouragement, travel, weather, keyword, inbox
}
```

Uniqueness invariant: at most one non-dismissed insight per
`(dayKey, kind)`. The orchestrator enforces this on save (delete existing
matching rows before insert).

#### Generators

Each generator conforms to `InsightGenerator`:

```swift
@MainActor
protocol InsightGenerator {
    var kind: InsightKind { get }
    func generate(for day: DayContext) async -> AIInsight?
}

struct DayContext: Sendable {
    let weekOffset: Int
    let dayIdx: Int
    let events: [Event]
    let inbox: [InboxSuggestion]
    let now: Date
    let appleIntelligenceEnabled: Bool
}
```

##### `TravelInsightGenerator`

- For each event with `location != nil` and starting in the next 4 hours
  AND more than 10 minutes from now:
  - Geocode location → `CLLocationCoordinate2D` via `CLGeocoder` (cached).
  - `MKDirections.calculate(from: currentLocation, to: destination)`.
  - Compute `departureBy = event.start - directions.expectedTravelTime - 5min buffer`.
  - If `now < departureBy < now + 60min`, emit:
    `"Leave by HH:mm for <event.title>"`
- `actionURL`: `http://maps.apple.com/?daddr=<coords>&dirflg=d`
- `priority`: 0 (highest — time-sensitive).
- Color: `#FFE680` (yellow, attention).
- Skips if location auth not granted or `CLGeocoder` fails.

##### `WeatherInsightGenerator`

- Calls `WeatherService.shared.weather(for: currentLocation)`.
- Inspects `hourly` forecast for the day window.
- If any hour overlapping an event has `precipitationChance > 0.4`:
  emit `"Bring an umbrella — rain at <h>pm"`.
- If max temp delta vs yesterday > 15°F: emit a "Bundle up" or "Dress
  light" variant.
- `actionURL`: `weather://` (system Weather app).
- `priority`: 1.
- Color: `#C9F0E0` (mint).
- Requires `com.apple.developer.weatherkit` entitlement.
- Cached 30 minutes per (location, day).

##### `KeywordInsightGenerator`

- Foundation Models `LanguageModelSession.respond(to:generating:)` over:

  ```swift
  @Generable
  struct KeywordInsightDraft {
      @Guide(description: "Short handwritten nudge, max 60 chars, no emoji.")
      var text: String
      @Guide(description: "UUID of the related event from the input list, or empty if none.")
      var relatedEventID: String
      @Guide(description: "Confidence 0.0–1.0 that this nudge is useful.")
      var confidence: Double
  }
  ```

- Prompt:
  > Given today's events, generate at most one short, encouraging nudge
  > that references a meaningful detail (birthday, anniversary,
  > deadline, named person). Skip if nothing notable. Stay ≤ 60 chars.

- If `confidence < 0.6`, drop.
- `actionURL`: `weeklyplanner://event/<uuid>` if `relatedEventID` non-empty.
- `priority`: 2.
- Color: `#FFCCC9` (pink).
- Reuses the existing `IntelligenceService` env. Falls back to silence
  when Apple Intelligence is off (no fallback string — encouragement
  generator handles the empty cascade case).

##### `InboxInsightGenerator`

- Synchronous count of pending `InboxSuggestion` rows for the day.
- If `count > 0`: emit `"<n> inbox suggestion(s) for today"`.
- `actionURL`: `weeklyplanner://inbox/<dayKey>` → scroll to inbox block.
- `priority`: 3.
- Color: `#E0DFFF` (lavender — new in `PaperTheme.stickyColors`).
- No AI dependency.

##### `EncouragementInsightGenerator` (fallback)

- Renamed existing `StickyInsightGenerator`.
- Runs only when the orchestrator's primary cascade returns 0 results.
- `priority`: 9.
- Color: any of `["#FFE680", "#C9F0E0", "#FFCCC9"]` (deterministic).

#### `StickyOrchestrator`

```swift
@MainActor
final class StickyOrchestrator {
    private let generators: [any InsightGenerator]
    private let fallback: EncouragementInsightGenerator
    private let cache: TTLCache<String, [AIInsight]>     // 5-min TTL

    func run(for day: DayContext, into context: ModelContext) async {
        if let cached = cache.get(day.cacheKey) {
            persist(cached, into: context, day: day)
            return
        }
        let results: [AIInsight] = await withTaskGroup(of: AIInsight?.self) { group in
            for gen in generators {
                group.addTask { await gen.generate(for: day) }
            }
            var out: [AIInsight] = []
            for await result in group { result.map { out.append($0) } }
            return out
        }
        let final = results.isEmpty
            ? [await fallback.generate(for: day)].compactMap { $0 }
            : Array(results.sorted(by: { $0.priority < $1.priority }).prefix(3))

        cache.set(day.cacheKey, final)
        persist(final, into: context, day: day)
    }

    private func persist(_ insights: [AIInsight], into: ModelContext, day: DayContext) {
        // delete existing rows for (dayKey, kind) covered by insights;
        // insert new; save.
    }
}
```

- `cacheKey = "\(weekOffset):\(dayIdx):\(eventsHash)"` — busts on event mutation.
- `events:hash` is a stable hash of the day's event ids + start times.

#### UI — `AIStickyStack`

Replaces `AIStickyNote` as the public surface mounted from `DayPageContent`.

- Renders up to 3 stickies in a `ZStack`:
  - Top sticky: full size, tilt from data, no offset.
  - Second sticky (if present): offset `y: 8, x: -4`, tilt `data.tilt - 2°`,
    z-order beneath, slightly darker shadow.
  - Third (if present): offset `y: 14, x: -8`, tilt `data.tilt - 4°`, even
    further behind.
- Eyebrow row gains a tiny "↻" SF Symbol button on the trailing edge
  — tap → calls `viewModel.refreshInsights()`.
- Body tap → opens `actionURL` (via `UIApplication.open` for external, via
  `DeepLinkRouter.request(.event)` / `.inbox` for internal schemes).
- Body long-press → context menu:
  - `"Show another"` — promotes the next sticky in cascade.
  - `"Dismiss this insight"` — sets `dismissed = true`, refreshes stack.
  - `"Refresh"` — re-runs orchestrator.
  - Action-specific row when `actionURL` non-nil: "Get directions" /
    "Open in Weather" / "Open event" / "Open inbox".
- Promote animation: tapped sticky scales 1.0 → 0.92, slides down 24pt
  with `stickyPeel` curve, fades to opacity 0; next sticky scales 0.96 →
  1.0 in parallel. ~0.32s total.
- Cycle behavior: tapping the last sticky cycles back to the first.
- Accessibility:
  - `.accessibilityElement(children: .contain)` on the stack.
  - Each sticky gets its own label "<kind>: <text>".
  - Rotor "Insights" added to `DayPageContent`.
  - `↻` button has its own label "Refresh insights".

#### Wiring

- `DayPageViewModel.refresh()` now calls `StickyOrchestrator.run(...)`
  on every refresh (already runs on `.task` + pull-to-refresh — Phase 18
  hook).
- `DayPageViewModel` exposes `insights: [AIInsight]` (sorted, dismissable).
- `StickyOrchestrator` is constructed in `WeeklyPlannerApp.init` with
  injected dependencies: `WeatherService.shared`, `CLLocationManager`,
  `IntelligenceService`, and the runtime `ModelContext`. Test path uses
  in-process fakes.

#### Entitlement + capability

- Add to `WeeklyPlanner/Supporting/WeeklyPlanner.entitlements`:

  ```xml
  <key>com.apple.developer.weatherkit</key>
  <true/>
  ```

- Apple Developer Portal: enable WeatherKit capability on the
  `com.weeklyplanner.WeeklyPlanner` App ID. Documented in
  `phase-24-ai-sticky-v2.md` Risks section.
- `Info.plist` already declares `NSLocationWhenInUseUsageDescription`
  (Phase 19). `MKDirections` reuses that authorization tier; no new key.

### Files

```
WeeklyPlanner/Models/AIInsight.swift                                    # MODIFY (+kind, +actionURL, +priority; v2 schema)
WeeklyPlanner/Intelligence/InsightGenerator.swift                       # NEW (protocol + DayContext)
WeeklyPlanner/Intelligence/StickyOrchestrator.swift                     # NEW
WeeklyPlanner/Intelligence/Tasks/TravelInsightGenerator.swift           # NEW
WeeklyPlanner/Intelligence/Tasks/WeatherInsightGenerator.swift          # NEW
WeeklyPlanner/Intelligence/Tasks/KeywordInsightGenerator.swift          # NEW
WeeklyPlanner/Intelligence/Tasks/InboxInsightGenerator.swift            # NEW
WeeklyPlanner/Intelligence/Tasks/EncouragementInsightGenerator.swift    # RENAME from StickyInsightGenerator.swift (fallback only)
WeeklyPlanner/Features/DayPage/AIStickyStack.swift                      # NEW (replaces single AIStickyNote at the page level)
WeeklyPlanner/Features/DayPage/AIStickyNote.swift                       # MODIFY (gains `onTap`, `onLongPress` action callbacks; loses its own state-machine ownership)
WeeklyPlanner/Features/DayPage/StickyNoteGenerator.swift                # MODIFY (returns [AIInsight], not just first)
WeeklyPlanner/Features/DayPage/DayPageView.swift                        # MODIFY (stickyNoteOverlay → AIStickyStack)
WeeklyPlanner/Features/DayPage/DayPageViewModel.swift                   # MODIFY (insights array, refreshInsights, dismissInsight)
WeeklyPlanner/App/WeeklyPlannerApp.swift                                # MODIFY (orchestrator + WeatherService injection)
WeeklyPlanner/Supporting/WeeklyPlanner.entitlements                     # MODIFY (+weatherkit)
project.yml                                                             # MODIFY (Capabilities entry)
WeeklyPlannerTests/Intelligence/StickyOrchestratorTests.swift           # NEW
WeeklyPlannerTests/Intelligence/TravelInsightGeneratorTests.swift       # NEW
WeeklyPlannerTests/Intelligence/WeatherInsightGeneratorTests.swift      # NEW
WeeklyPlannerTests/Intelligence/KeywordInsightGeneratorTests.swift      # NEW
WeeklyPlannerTests/Intelligence/InboxInsightGeneratorTests.swift        # NEW
WeeklyPlannerTests/DayPage/AIStickyStackTests.swift                     # NEW
WeeklyPlannerTests/Models/AIInsightV2MigrationTests.swift               # NEW
```

### Tests (TDD)

Per-generator (~5 each, all using fakes for MapKit/WeatherKit/IntelligenceService):
- Happy path emits expected text + URL + priority.
- No data → returns nil.
- Threshold edges (e.g., travel time < 10 min from now → nil).
- Auth/availability denied → returns nil.
- Caching honored.

`StickyOrchestratorTests`:
- Cascade order: travel > weather > keyword > inbox > encouragement.
- Cap at 3 results.
- Empty primary → encouragement fallback runs.
- TTL cache: second call within 5 min returns cached without re-running generators.
- `dismissed=true` row excluded.

`AIStickyStackTests`:
- 0 insights → empty view.
- 1 insight → single sticky, no peek layers.
- 2 insights → top + 1 peek.
- 3 insights → top + 2 peeks.
- Tap top sticky → promotes next (state machine).
- Tap-cycle wraps from last back to first.

`AIInsightV2MigrationTests`:
- Schema migration from v1 row (missing kind/actionURL/priority) → v2
  with `kind = .encouragement, actionURL = nil, priority = 9`.

UITest:
- `AIStickyStackUITests.testTapTravelSticky_attemptsToOpenMaps` — uses
  a URL stub.

### Acceptance criteria

- An event with a location, starting within 4 hours, triggers a travel
  sticky within one refresh cycle (~2s).
- Rainy hours overlap an event → weather sticky appears.
- A day with the title "Sara's birthday" → keyword sticky surfaces a
  nudge that references Sara.
- A day with pending inbox suggestions → inbox sticky appears with the count.
- Up to 3 stickies render in the cascade; tapping the top promotes the
  next; tapping the last cycles back.
- Pull-to-refresh and "↻" both trigger orchestrator re-runs.
- Long-press → context menu with the right actions per `kind`.
- All `XCUIAccessibilityAudit` tests still green; rotor "Insights"
  works in VoiceOver.

### Out of scope

- Push-notification-driven insight refresh (insights only refresh on
  in-app interactions).
- Custom user-defined insight rules ("always remind me to floss before bed").
- Cross-day insights (e.g., "you have 4 birthdays this week").

### Risks

- **WeatherKit entitlement provisioning.** The capability must be added
  to the App ID in the Apple Developer portal before Xcode will sign a
  build with the entitlement. If not provisioned, builds fail with
  "Provisioning profile doesn't include the com.apple.developer.weatherkit
  entitlement." Mitigation: document the portal step in the phase doc;
  test target uses a `StubWeatherProvider` so unit tests don't depend on
  the entitlement.
- **`MKDirections` request quota.** Apple throttles ~50 reqs/min/device.
  Cache geocodes + directions per `(eventID, dayHash)` for 1 hour.
- **Foundation Models `@Generable` Optional gotcha** (per Phase 18
  retrospective): keep `relatedEventID: String` non-optional with empty
  string sentinel.
- **SwiftData v1 → v2 migration.** Use lightweight migration
  (`MigrationPlan.willMigrate / didMigrate`); default new fields. Existing
  `AIInsight` rows from Phase 13b stay valid.
- **Cascade gesture conflicts.** Tap-to-promote on the top sticky and
  body-tap-to-open-action both consume the tap. Resolution: tap = action,
  promote moves to the explicit "↻" or context-menu "Show another".
  (Revised from the brainstorm — tap-to-cycle was ambiguous; tap-to-open
  matches user expectation that tapping a notification-style card opens it.)

---

## Cross-phase concerns

### Branch + merge strategy

- Branch off `main`: `git checkout -b milestone-j-completeness`.
- Each phase = one PR titled `feat(phase-NN): <slug>`.
- Phase 22 lands first (most contained), then 23 (depends on shared
  `InkTextField`), then 24 (largest, depends on nothing in 22/23 but
  ordered last for risk).
- After Phase 24, the milestone merges to `main` and `Milestone K`
  (Ship) runs on a fresh `milestone-k-ship` branch.

### Test budget

| Phase | Unit Tests | UI Tests | Total |
|-------|-----------|----------|-------|
| 22    | ~10       | 1        | ~11   |
| 23    | ~12       | 1        | ~13   |
| 24    | ~30       | 1        | ~31   |
| **Σ** | **~52**   | **3**    | **~55** |

Suite target: **302 → ~357 unit + ~12 UI**.

### Phase 21 deviations to honor

- `theme.ink2` (not `inkMuted`) — see [[phase-18-deviations]].
- Per-iter `do/catch` around generator calls in the orchestrator.
- `@preconcurrency` for any UIKit delegate seam if added.
- New `Text("...")` literals will be picked up by Xcode's catalog scanner
  on GUI builds — CLI builds leave `Localizable.xcstrings` unchanged.

### Things explicitly NOT in this milestone

- Modern Mode revival. Phase 20 stays archived.
- Snapshot tests. Still deferred to a hypothetical Phase 27.
- Cross-device sync (CloudKit). Not in v1.0.

---

## Sign-off

- Spec approved 2026-05-22 PT.
- Branch created: `milestone-j-completeness`.
- Next step: writing-plans skill for **Phase 22** (Manual Event CRUD).
