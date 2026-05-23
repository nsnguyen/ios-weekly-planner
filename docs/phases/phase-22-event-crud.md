# Phase 22 — Manual Event CRUD

## Goal
Let the user create new events on the Day page via a floating ink "+" button, and edit existing events' title / start / end / category / location through the same `PaperEventSheet`. Save round-trips through `EventKitMirroringEventStore` so changes land in real iOS Calendar.

## Why this is needed
v1.0 currently surfaces only events synced from EventKit + Gmail. Without manual CRUD, the app is read-only from the user's perspective — every event has to come from outside the planner.

## Prerequisites
- Phase 04 (EventKit gateway + mirror), Phase 11 (`PaperEventSheet` exists), Phase 16 (Settings live-injection of theme/font/size), Phase 19 (notification rescheduling on `.eventStoreDidChange`), Phase 21 (accessibility patterns).

## Files Created / Modified

```
WeeklyPlanner/Features/EventDetail/EventComposerState.swift                # NEW
WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift              # NEW
WeeklyPlanner/Features/EventDetail/EditableFields/InkTextField.swift       # NEW
WeeklyPlanner/Features/EventDetail/EditableFields/PaperDateTimeRow.swift   # NEW
WeeklyPlanner/Features/EventDetail/EditableFields/CategorySwatchRow.swift  # NEW
WeeklyPlanner/Features/EventDetail/EditableFields/LocationField.swift      # NEW
WeeklyPlanner/Features/DayPage/FloatingInkButton.swift                     # NEW
WeeklyPlanner/Navigation/AppShell.swift                                    # MODIFY — mount FAB + isAnySheetOpen env
WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift                   # MODIFY — SheetMode dispatch
WeeklyPlanner/Features/EventDetail/EventDetailViewModel.swift              # MODIFY — save/cancel + composer init
WeeklyPlannerTests/EventDetail/EventComposerStateTests.swift               # NEW
WeeklyPlannerTests/EventDetail/PaperEventSheetEditTests.swift              # NEW
WeeklyPlannerUITests/EventCreateFlowUITests.swift                          # NEW
```

## Visual & Interaction Checklist

### `FloatingInkButton`
- [ ] 56×56 circle, ink-stroke border (1.4pt) in `theme.ink`.
- [ ] "+" rendered via SwiftUI `Canvas` as two perpendicular ink strokes (3pt wide, slightly off-center for hand-drawn feel).
- [ ] Background: `theme.cream` with 0.96 opacity (so leather shows through faintly).
- [ ] Shadow: `0 2 4 rgba(0,0,0,0.18)`.
- [ ] Position: anchored bottom-trailing at the `AppShell` level. Offset 24pt from trailing edge, `Spacing.tabBarHeight + 20pt` above the tab bar.
- [ ] Hides when any sheet is open (`@Environment(\.isAnySheetOpen)`).
- [ ] Long-press → menu: "New event" / "New task" (Phase 23 wires second action).
- [ ] Accessibility: label `"Add event"`, hint `"Opens new event composer"`, trait `.isButton`, id `appshell.fab.add`.

### `PaperEventSheet` in `.create` / `.edit` mode
- [ ] Header keeps the same torn-paper chrome but the title becomes an `InkTextField` bound to `composer.title`.
- [ ] Close `×` is replaced by `"Save"` (right) and `"Cancel"` (left) handwriting actions.
- [ ] `Save` is disabled when `!composer.canSave`; reads `theme.ink3` until valid, then `theme.blueInk`.
- [ ] Below title:
  - [ ] `PaperDateTimeRow("Starts", $composer.start)`.
  - [ ] `PaperDateTimeRow("Ends", $composer.end)` — text becomes `theme.redInk` if end ≤ start.
  - [ ] `CategorySwatchRow($composer.category)` — 4 ink dots, selected gets hand-drawn ring.
  - [ ] `LocationField($composer.location)` with leading `mappin.circle` glyph in `theme.ink3`.
  - [ ] Existing `EventAlertRow` and `EventLocationAlertRow` retained.
- [ ] Delete button hidden in `.create` mode; visible in `.edit`.
- [ ] Cancel with dirty composer → `.confirmationDialog("Discard changes?")` two-button.

### `InkTextField`
- [ ] Wraps SwiftUI `TextField`. No border. Caret tint `theme.blueInk`.
- [ ] Placeholder italicized in `theme.ink2`.
- [ ] Font: `font.font(at: 17 * size.scale)` — matches body handwriting size.
- [ ] When focused, draws a 1pt blue-ink wavy underline (reuse `WavyUnderline`) beneath the baseline.
- [ ] Title variant uses 22pt; location/body variants use 15pt.

### `PaperDateTimeRow`
- [ ] Leading handwriting label ("Starts"/"Ends") in `theme.ink`, 15pt.
- [ ] Trailing `DatePicker(.compact)` styled to use handwriting font for date and time chips via `.environment(\.font, ...)`.
- [ ] `.environment(\.colorScheme, theme.isDark ? .dark : .light)` so the picker popover doesn't fight midnight theme.

### `CategorySwatchRow`
- [ ] 4 dots, 22pt each, gap 14pt — colors from `PaperTheme.inkColors` (personal/work/health/family).
- [ ] Selected: 1.5pt ink-stroke ring drawn via `Circle().stroke()`.
- [ ] Tap = select. Each swatch has `.accessibilityValue("\(category) — selected")` when active.

### `LocationField`
- [ ] `InkTextField` variant prefixed by `Image(systemName: "mappin.circle")` (15pt, `theme.ink3`).
- [ ] Placeholder `"Location"` — italic.

## Logic & Data Checklist

### `EventComposerState`
- [ ] `@MainActor @Observable final class`.
- [ ] Fields: `title`, `start`, `end`, `category`, `location`, `alertOn`, `alertMinutes`, `locationAlertOn`.
- [ ] Computed: `titleIsValid` (non-empty trimmed), `timesAreValid` (end > start), `canSave` (both).
- [ ] Static `empty(at:calendar:)` — default `start = nextHour(date)`, `end = start + 1h`, `category = .personal`.
- [ ] Static `from(_ event: Event)` — round-trip every editable field.
- [ ] `build(id: UUID = UUID()) -> Event` — sets `source = .manual`.
- [ ] `func isDirty(against: EventComposerState) -> Bool` — for cancel-confirm.

### `PaperEventSheet.SheetMode`
- [ ] `enum SheetMode { case view, edit(eventID: UUID), create(at: Date) }`.
- [ ] `init` overloads: existing for `.view`, new for `.create(at:)` and `.edit(eventID:)`.
- [ ] `.task(id: mode)` reseeds composer state when mode changes (e.g., view → edit).

### `EventDetailViewModel`
- [ ] `var composer: EventComposerState?` — nil in `.view`, set in `.edit`/`.create`.
- [ ] `func save() async` — calls `eventStore.upsert(composer.build())`, refreshes self.
- [ ] `func cancel() -> Bool` — returns true if dirty (caller shows discard confirm).
- [ ] Save success → posts `.eventStoreDidChange` (the store does it).

### `AppShell` integration
- [ ] New env key `\.isAnySheetOpen: Bool` (default false). Set true when `eventSheetID != nil`, `weekPickerOpen`, or `aiSearchOpen`.
- [ ] `FloatingInkButton` mounted at the `ZStack` root of `AppShell` so it overlays the active tab.
- [ ] Tap → set `creatingEvent = true`; `DayPage`/`WeekPage` observe and open `PaperEventSheet(mode: .create(at: focusedDate))`.

### Time picker behavior
- [ ] When user advances `start` past `end`, `end` auto-bumps to `start + 1h` (single-shot; user can override afterwards).
- [ ] Date and time use the same `DatePicker` (mode `.dateAndTime` graphical popover on tap).

## Tests (TDD)

`EventComposerStateTests`
- [ ] `testEmptyDefaults_startNextHour_endPlusOne`.
- [ ] `testFromEvent_roundTrips`.
- [ ] `testCanSave_falseWhenTitleEmpty`.
- [ ] `testCanSave_falseWhenEndBeforeStart`.
- [ ] `testBuild_setsSourceManual`.
- [ ] `testIsDirty_detectsChanges`.

`PaperEventSheetEditTests`
- [ ] `testCreateMode_saveCallsUpsert`.
- [ ] `testEditMode_saveUpdatesExistingEvent`.
- [ ] `testCancelWithDirtyState_promptsConfirm`.
- [ ] `testTimePickerEdge_endAutoBumpsWhenStartAdvancesPastEnd`.

`EventCreateFlowUITests`
- [ ] `testCreateEvent_endToEnd` — tap FAB, fill title "Lunch with Jamie", pick 12:00–13:00, save; assert row appears in Day page event list and `eventStore.events(forWeekOffset: 0)` contains it.

## Acceptance Criteria
- Floating "+" appears on Day + Week pages; tap opens an empty `PaperEventSheet` in `.create` mode.
- Tap an existing event → sheet opens in `.edit` mode; pencil ink-glyph in header indicates editability.
- Saving a new event makes it appear in the same Day page row list within one frame.
- Cancel from a dirty composer prompts "Discard changes?"
- Real iOS Calendar shows the new/edited event.
- All `XCUIAccessibilityAudit` UI tests still green; FAB has VoiceOver label.

## Out of Scope
- Recurrence rules.
- Attendees / invitees editing.
- Cross-day events (start/end on different dates).
- Inline-on-page editing (no sheet) — sheet-only.

## Risks & Notes
- **Keyboard occlusion** on smaller devices — `InkTextField` must scroll the sheet up. Use `.safeAreaInset(edge: .bottom)` for the keyboard area.
- **`@Observable` + `@Bindable`** — composer state must use `@Bindable var state` inside the sheet for two-way bindings to work with `TextField` / `DatePicker`. Phase 16 used the same pattern.
- **EventKit upsert latency** — `MainActor`-isolated mirror may queue under rapid Save spamming. Acceptance only requires optimistic UI; the SwiftData write is synchronous, EventKit roundtrip is best-effort.
- **`theme.ink2` (not `inkMuted`)** — see Phase 18/19 deviations.
