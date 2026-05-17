# Phase 07 — Day Page To-Do Block & AI Sticky Note

## Goal
Add the two remaining day-page overlays: the dashed yellow To-Do patch at the bottom (with ink checkboxes + wavy "To-do" underline + priority bang) and the peelable AI sticky note at the top-right corner.

## Why this is needed
These are signature visual elements. The sticky note's peel animation is one of the defining interactions.

## Prerequisites
- Phase 02 (theme, typography, AnimationTokens), 03 (`TaskItem`, `AIInsight`), 05 (`MaskingTape`, `WavyUnderline`, `DashedBorder`), 06 (DayPageView exists, accepts overlay children).

## Files Created / Modified

```
WeeklyPlanner/Features/DayPage/TodoBlock.swift                # NEW — dashed yellow patch container
WeeklyPlanner/Features/DayPage/TodoRow.swift                  # NEW — checkbox + handwriting title + priority
WeeklyPlanner/Features/DayPage/AIStickyNote.swift             # NEW — peelable masking-tape note
WeeklyPlanner/Features/DayPage/AIStickyTab.swift              # NEW — folded 22×22 tab state
WeeklyPlanner/Features/DayPage/StickyNoteGenerator.swift      # NEW — picks insight by (weekOffset, dayIdx) → uses AIInsight from store; if missing, requests from Foundation Models (Phase 13).
WeeklyPlanner/Features/DayPage/DayPageView.swift              # MODIFY — composes todo block + sticky note
WeeklyPlannerTests/DayPage/TodoBlockTests.swift               # NEW
WeeklyPlannerTests/DayPage/AIStickyNoteTests.swift            # NEW (peel animation state machine)
WeeklyPlannerTests/DayPage/TodoSnapshotTests.swift            # NEW
WeeklyPlannerTests/DayPage/StickySnapshotTests.swift          # NEW
```

## Visual & Interaction Checklist

### `TodoBlock` (renders only when `tasks.count > 0` for the focused day)
- [ ] Positioned absolutely: `bottom: 18, leading: 44, trailing: 18`. Width fills.
- [ ] Padding `10 12 8 12` (top, trailing, bottom, leading).
- [ ] Background `rgba(255,255,200,0.35)`.
- [ ] Border: 0.5pt dashed in `theme.ink3`. Radius 2pt.
- [ ] Header text `"To-do"` in handwriting 17pt weight 700, color `theme.blueInk`, `marginBottom 6`.
- [ ] **Wavy underline** beneath header — color `rgba(26,58,122,0.3)` (blue-ink 30%).
- [ ] Followed by a `VStack` of `TodoRow`s.

### `TodoRow`
- [ ] Horizontal flex row, gap 8pt, padding `2pt vertical`.
- [ ] **Checkbox**: 15×15. Border 1.4pt `theme.ink`. Radius 1pt. Background `#FFFFFF`.
- [ ] When `task.done`: inner SVG check (13×13 viewBox), stroke 2pt `theme.blueInk`, path `M2 7 l3 3 l6 -7`, round line caps/joins.
- [ ] **Title**: handwriting 17pt, color `theme.ink` if not done; `theme.ink2` if done.
- [ ] When `task.done`: title strikethrough; strikethrough color `theme.redInk`.
- [ ] **Priority bang**: when `task.priority == .high && !task.done`, append a `"!"` glyph in `theme.redInk`, 16pt, weight 700, on the trailing edge.
- [ ] Whole row tappable → `TaskStore.toggle(id:)`. Animation: 0.15s ease-out on the checkmark scale + opacity.
- [ ] Accessibility: `accessibilityLabel("\(task.title), \(done ? "completed" : "not completed")")`, `accessibilityAddTraits(.isButton)`.

### `AIStickyNote` (expanded state)
- [ ] Positioned `top: 16, trailing: 16` on the Day Page.
- [ ] Width 104. Padding `8 9 10 9`.
- [ ] Background = `insight.colorHex` (e.g., `#FFE680` yellow, `#C9F0E0` mint, `#FFCCC9` pink).
- [ ] Rotation `insight.tiltDegrees` (±3°–5°).
- [ ] Shadow: `0 3 8 rgba(0,0,0,0.22), 0 1 2 rgba(0,0,0,0.12)`.
- [ ] Radius 1pt (almost square — paper, not rounded card).
- [ ] **Masking tape** at top-center: 32×10, color `rgba(180,140,70,0.45)`, offset upward 5pt.
- [ ] **Bottom-right peel corner hint**: 12×12 gradient (135°), `transparent 50% → rgba(0,0,0,0.08) 50% → rgba(0,0,0,0.18) 100%`.
- [ ] **Eyebrow** row: system 8pt weight 700, letter-spacing 1.2, color `rgba(0,0,0,0.4)`, marginBottom 3, content: small sparkles icon (9×9) + `"AI"`.
- [ ] **Body text**: handwriting 13pt weight 600, color `#3A2A1A`, line-height 1.15.
- [ ] Tap → switches to folded state.
- [ ] Spring animation `Animation.timingCurve(0.2, 0.8, 0.2, 1.1, duration: 0.32)` — `cubic-bezier(0.2,0.8,0.2,1.1)` with overshoot.
- [ ] Transform origin: top-right.

### `AIStickyTab` (folded state)
- [ ] 22×22 container.
- [ ] Position shifts to `top: 4, trailing: 96` — above and to the left, away from the giant date.
- [ ] Background: gradient at 225° — `noteColor` 0–55%, `rgba(0,0,0,0.18)` 56%, `shade(noteColor, -20)` 100%. Implement `shade()` helper that darkens a hex by N%.
- [ ] Rotation `tilt - 6°`.
- [ ] Sparkles icon (11×11) centered, color `rgba(0,0,0,0.6)`.
- [ ] Tap → expand back to full sticky.

### Sticky note generation policy
- [ ] Source 1: `AIInsight` rows persisted in SwiftData (created by Phase 13's Foundation Models generator).
- [ ] Source 2: hard-coded seed map (from `paper-planner.jsx` `insights` object) for the days listed in the mock — used in DEBUG seed.
- [ ] If no insight for `(weekOffset, dayIdx)`, sticky is **omitted** (not blank).
- [ ] Per-day refresh policy: insights regenerate at most once per day (timestamp check). Implementation in Phase 13.

## Logic & Data Checklist

### State machine — sticky note
- [ ] `enum StickyState { case expanded, folded }`.
- [ ] Toggled on tap. Animated transition; the entire view smoothly interpolates position + rotation + scale.
- [ ] Persist `folded` state across page flips? **No** — flipping a page resets to expanded (matches expected mock behavior — verify by reading `paper-planner.jsx`).
- [ ] Drag gesture stretch goal: a tiny drag down → instant fold. Stretch — implement if Phase 11 budget allows.

### Wiring
- [ ] `DayPageView` composes `EventEntryList`, `InboxBlock`, `TodoBlock` (bottom), `AIStickyNote` (top-right), all stacked over `BookPage`.
- [ ] If both `EventEntryList` is empty AND `InboxBlock` is empty, `EmptyDayState` from Phase 06 is shown — but `TodoBlock` and `AIStickyNote` still render if they have content (the to-do patch sits above the page footer; the sticky note in the corner).
- [ ] Layout: when `TodoBlock` is present, ensure events don't overlap. The events list `paddingBottom` increases to ~120pt to clear the patch.

## Tests (TDD)

`TodoBlockTests`
- [ ] `testTodoBlockHiddenWhenNoTasks()`.
- [ ] `testTodoRowTapTogglesDoneViaStore()`.
- [ ] `testHighPriorityBangShownOnlyForOpenHighTasks()`.

`AIStickyNoteTests`
- [ ] `testInitialStateIsExpandedWhenInsightAvailable()`.
- [ ] `testTapTransitionsToFolded()`.
- [ ] `testTapAgainExpands()`.
- [ ] `testStickyOmittedWhenNoInsight()`.
- [ ] `testShadeHelperDarkensColorCorrectly()` — `shade("#FFE680", -20)` ≈ `#CCB866`.

`TodoSnapshotTests`
- [ ] Snapshot Saturday day (has buy gift, water plants, confirm dinner) — verifies done states + priority bang.
- [ ] Snapshot under cream + midnight.

`StickySnapshotTests`
- [ ] Expanded yellow note at Saturday (`"Don't forget Sara's gift!"`) at tilt +4°.
- [ ] Folded 22×22 tab variant.
- [ ] Mint/pink variants from Thursday/Friday.

## Acceptance Criteria
- Tapping a checkbox flips it instantly; line-through + dim animates.
- Tapping the sticky folds it; tap again expands. Animation includes overshoot.
- Long-press accessibility action: `"Toggle task done"` and `"Toggle AI note"` work with VoiceOver.
- Side-by-side visual diff with the mock for Saturday + Friday + Wednesday days.

## Out of Scope
- Adding new tasks from this page (Phase 11 — uses the event sheet pattern for editing).
- Sticky drag gesture (stretch).
- Multi-line sticky text (mock body is short by design).

## Risks & Notes
- **Sticky transform origin** must be top-right or the spring-back animation looks wrong.
- **The folded tab's gradient** is non-obvious — verify with screenshot tool against the mock at 3× scale.
- **DEBUG seed insights** must use the exact text strings from the mock (`"Don't forget Sara's gift!"`, etc.). Production builds will generate insights via Foundation Models in Phase 13.
