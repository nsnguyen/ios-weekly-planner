# Phase 28 — Sticky Note Swipe-Lock Fix

> **Milestone K (Critical Fixes).** Submission blocker — Phase 41 (App Store
> Submission) waits on this.
> Derived from `docs/suggestions.md` line 4. AI Sticky Notes stay **opt-in**
> per `[[ai-sticky-notes-opt-in]]`; this phase fixes only the swipe-lock.

## Goal
Ensure that having an AI sticky note enabled (and visible) can never block
page navigation: an interrupted or completed sticky gesture must always
restore the page-flip swipe, with no relaunch required.

## Why this is needed
Suggestion 4: *"When sticky note on, unable to swipe page or change page
unless reboot."* `DayPageView` yields the page-flip gesture to the sticky
while a sticky drag is active —
`.horizontalSwipe { ... guard !controller.stickyDragActive else { return } ... }`
(`DayPageView.swift:51`). `stickyDragActive` is a plain flag set by
`AIStickyStack` at gesture start. If the gesture is interrupted (finger lifted
outside the tracked frame, the view rebuilt mid-drag by a refresh/tick, the
sticky dismissed mid-swipe), the reset to `false` can be missed — leaving the
flag stuck `true` and **every** page-flip permanently suppressed until the app
restarts. A prior pass wired this suppression (2026-05-24) but the reset is
not interruption-proof.

## Prerequisites
- Phase 24 (AI Sticky v2) and the opt-in change (2026-05-28).
- **Phase 27** (the flip lifecycle this depends on is fixed there). Land 27 first.

## Investigation / Root-Cause Hypotheses
Use `superpowers:systematic-debugging`. Likely causes:

1. **`stickyDragActive` never reset on interruption.** The `DragGesture`'s
   `.onEnded` is the only place it flips back to `false`; SwiftUI does not
   guarantee `.onEnded` fires when a gesture is cancelled or the view is torn
   down. Need a `.onChange`/`@GestureState`-backed reset that returns to
   `false` automatically when the gesture is no longer active, plus a reset on
   `onDisappear` and on `insights` becoming empty.
2. **Single-sticky vs stack.** With one insight there's nothing to swipe
   between; confirm the gesture still arms/disarms cleanly and doesn't claim
   the page swipe when navigation between stickies is impossible.
3. **Opt-in gating interaction.** The overlay is gated on
   `aiStickyNotesEnabled != false`. Confirm toggling the setting off while a
   drag is mid-flight also clears `stickyDragActive`.

## Files Created / Modified

```
WeeklyPlanner/Features/DayPage/AIStickyStack.swift        # MODIFY — derive stickyDragActive from @GestureState; reset on cancel/disappear/empty
WeeklyPlanner/Features/DayPage/DayPageView.swift          # REVIEW — the .horizontalSwipe guard (line ~51); ensure no permanent suppression
WeeklyPlanner/Features/DayPage/PageFlipController.swift   # REVIEW — stickyDragActive ownership; consider auto-clear on commit/cancel
WeeklyPlanner/Features/WeekPage/WeekStickyNote.swift      # REVIEW — week-page sticky must not block week swipe the same way
WeeklyPlannerTests/DayPage/AIStickyStackTests.swift       # MODIFY — gesture cancel resets the flag
WeeklyPlannerUITests/StickySwipeUITests.swift             # NEW — sticky enabled + page still swipes after an aborted sticky drag
```

## Behavior Checklist
- [ ] With a sticky note enabled and showing, horizontal swipe on the page
      still flips the day.
- [ ] Starting a sticky drag and releasing **without** completing it leaves the
      page swipe working immediately afterward.
- [ ] Swiping between stacked stickies works, and afterward the page swipe
      still works.
- [ ] Dismissing the sticky mid-drag, or toggling AI Sticky Notes off mid-drag,
      restores the page swipe.
- [ ] Navigating away (Day → Week → Day) while a sticky is showing never leaves
      navigation suppressed.

## Logic & Data Checklist
- [ ] `stickyDragActive` is `true` **only** for the duration of an actual
      in-progress sticky drag and returns to `false` automatically when the
      gesture ends, cancels, or the view disappears — driven by gesture state,
      not a manual `.onEnded` side effect alone.
- [ ] The page-flip suppression guard cannot persist across a tree rebuild,
      refresh, or `.everyMinute` tick.
- [ ] No regression to Phase 24's swipe-between-stickies behavior.

## Tests (TDD)
`AIStickyStackTests`
- [ ] `testDragStateResetsOnGestureEnd()`
- [ ] `testDragStateResetsWhenInsightsBecomeEmpty()`
- [ ] `testSuppressionFlagFalseWhenIdle()`

`StickySwipeUITests` (UI)
- [ ] `testPageStillFlipsWithStickyEnabled()`
- [ ] `testAbortedStickyDragDoesNotLockNavigation()` — the core regression.

## Acceptance Criteria
- The swipe-lock is reproduced, root-caused, and fixed at the gesture-state
  level (not by removing the suppression entirely, which would reintroduce the
  Phase 24 gesture conflict).
- Checklist items pass; full suite green.
- On-device: enable sticky, perform several partial/aborted sticky drags, and
  confirm page navigation never locks.

## Out of Scope
- **Modify / remove an individual sticky note (suggestions 3, 24).** Deferred
  by the opt-in decision — users who don't want stickies turn the feature off
  in Preferences (already default-off). Revisit only if feedback persists.
- Removing the sticky feature entirely.
- Any sticky-content/generation changes.

## Risks & Notes
- The fix must preserve the Phase 24 reason `stickyDragActive` exists: without
  suppression, the sticky's horizontal drag and the page-flip fight. Replace a
  fragile manual reset with gesture-state-derived truth; don't delete the
  mechanism.
- Mirror the audit on `WeekStickyNote` so the week page can't develop the same
  lock.
