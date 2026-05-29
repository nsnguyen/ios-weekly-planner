# AI Sticky Notes → Opt-In

**Date:** 2026-05-28
**Status:** Approved, ready for implementation
**Author:** Nguyen + Claude

## Problem

The day-page AI sticky notes (top-right peelable paper notes) are on by default and
feel intrusive. A Settings toggle (`aiStickyNotesEnabled`) already exists, but it
defaults to **ON**, so every install shows the stickies until the user turns them off.
Worse, that toggle gates only *display* — the `StickyOrchestrator` cascade
(WeatherKit / MapKit / CoreLocation / FoundationModels) still runs on every day-page
refresh even when the notes are hidden.

## Decision

Make the feature **opt-in**: hidden *and* not generated unless the user explicitly
enables it. The feature stays fully intact behind the existing toggle — nothing is
deleted. Chosen over full removal (which is a ~half-day job with two SwiftData schema
migrations) because the Phase 24 work is worth preserving and the risk is far lower.

Out of scope: the look-alike-but-independent surfaces (Week-page sticky, event-detail
"Suggested" sticky, Week Review "Notes from AI"), and the separate
`appleIntelligenceEnabled` master gate — all left untouched.

## Changes

### 1. `WeeklyPlanner/Models/UserSettings.swift`
Flip the default `true → false` in both places:
- Stored-property default (`var aiStickyNotesEnabled: Bool = true`).
- `init` parameter default (`aiStickyNotesEnabled: Bool = true`).

New installs start with stickies off. The Settings toggle and its detail text
("Smart reminders on each day page") are unchanged — it simply becomes opt-in.

### 2. `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift`
Gate *generation*, not just display. Inject the existing `settingsStore` (optional,
defaults `nil`, matching the DI pattern `InboxStore` already uses) and read the flag
fresh inside `refresh()`:

```swift
let stickyEnabled = settingsStore == nil
    ? true                                                  // tests/previews: don't suppress
    : ((try? settingsStore!.current())?.aiStickyNotesEnabled ?? false)
if let orchestrator, let modelContext, stickyEnabled {
    await orchestrator.run(for: ctx, into: modelContext)
    insights = StickyNoteGenerator.insights(forWeekOffset: weekOffset, dayIdx: dayIdx, in: modelContext)
} else {
    insights = []
}
```

Reading fresh each refresh means a Settings toggle takes effect on the next page
refresh. The `nil`-store default of `true` keeps existing orchestrator-integration
tests green (they inject no settings store).

### 3. `WeeklyPlanner/Features/DayPage/DayPageView.swift`
In the `.task` block (VM construction), pass `settingsStore: settingsStore` (already
available via `@Environment(\.settingsStore)`). The display gate in `stickyNoteOverlay`
already checks the flag and stays as-is.

## Tests (TDD — red before green)

- **`DayPageViewModelTests`**: with a stub settings store reporting
  `aiStickyNotesEnabled = false` + a fake orchestrator, `refresh()` leaves `insights`
  empty and never invokes the orchestrator; with `= true`, it populates. (Verifies the
  generation gate.)
- **`UserSettings` default test**: asserts the new `false` default — documents the
  opt-in contract so a future change can't silently flip it back.
- Existing ~380 tests must stay green (nil-store path → enabled).

## Persistence caveat (honest note, not a code change)

Flipping the default affects only *fresh* state. The two already-installed devices have
`aiStickyNotesEnabled = true` persisted, so they keep showing stickies until toggled off
once (Settings → Preferences → AI Sticky Notes) or reinstalled. **No SwiftData schema
change**, so no migration and no crash-on-launch risk. A one-time "force off" migration
was considered and rejected: it would override anyone who deliberately enabled the
feature, and one tap on two personal devices is simpler.

## Verification

1. Regenerate the project via XcodeGen (source of truth).
2. Run the full unit suite — expect green plus the two new tests.

## Rollback

Fully reversible: revert the three edits (or just flip the two defaults back to `true`).
No data migration to undo.
