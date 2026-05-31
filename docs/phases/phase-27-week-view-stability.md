# Phase 27 — Week View Stability & Cross-View Navigation

> **Milestone K (Ship).** Submission blocker — Phase 26 must not go out until
> this is green. Derived from `docs/suggestions.md` lines 21–23 and the
> roadmap `docs/superpowers/specs/2026-05-30-post-launch-feedback-roadmap-design.md`.

## Goal
Eliminate the "everything freezes after ~1 minute" failure: restore reliable
week **and** day navigation via swipe, side tabs, chevrons, and the week
picker — and keep it reliable while the app sits idle on a page.

## Why this is needed
This is the single worst bug in TestFlight feedback. The app appears to lock
up: after roughly a minute on the Week view the user can no longer change
week or month, swipe and arrows stop responding, and **even the Day view can
no longer change date until the app is force-quit** (suggestion 21). Picking a
different week shows the old week's events (22); swipe and arrows are dead
(23). A planner that can't change the date is unusable. This must be fixed
before any public submission.

## Prerequisites
- Phases 09 (Top Bar & Week Picker), 10 (Week Page) complete. *(They are.)*

## Investigation / Root-Cause Hypotheses
Confirm the root cause with `superpowers:systematic-debugging` before editing —
do not fix blind. Leading hypotheses from the code survey:

1. **Stuck `isFlipping` (primary suspect).** `PageFlipController` rejects every
   `flipDay`/`flipToDay`/`flipWeek`/`setWeek` while `target != nil`
   (`guard !isFlipping else { return }`). The controller does **not** time its
   own `commit()` — the view layer schedules it after the animation. If that
   timed `commit()`/`cancel()` is ever dropped, `target` stays non-nil forever,
   `isFlipping` stays `true`, and **all** navigation (week and day) silently
   no-ops. This matches the symptom exactly, including Day view going dead.
2. **`TimelineView(.everyMinute)` as the trigger.** `TodayChip` (and any other
   `.everyMinute` timeline) fires its first tick ~1 minute in — the same
   "after a minute" window. A tick that rebuilds the tree mid-flip, or
   re-runs a `.task` that owned the pending `commit()`, can cancel the commit
   and strand `isFlipping`.
3. **Notification-driven refresh re-entrancy.** Day/Week pages refresh on
   `.eventStoreDidChange` / `.taskStoreDidChange` via `.onReceive`. Verify a
   refresh can't cancel an in-flight flip's commit task, and that a refresh
   never re-posts the same notification (a tick→refresh→notify→refresh loop
   would also present as a freeze).
4. **Week-pick offset not applied (suggestion 22).** `WeekPickerViewModel`
   computes `months` once and hands back `week.offset` on tap. Trace the tap
   through `WeekPickerSheet` → `PageFlipController.setWeek(_:)` →
   `WeekPageView`'s per-`weekOffset` lazy view model. Either the offset never
   reaches `setWeek`, or `setWeek` is a no-op because `isFlipping` is stuck
   (hypothesis 1), or the per-offset cached VM isn't refreshed for the new
   offset.

## Files Created / Modified

```
WeeklyPlanner/Features/DayPage/PageFlipController.swift     # MODIFY — guarantee commit/cancel; consider a controller-owned timeout
WeeklyPlanner/Features/DayPage/PageFlipContainer.swift      # MODIFY — robust commit scheduling that survives tree rebuilds
WeeklyPlanner/Features/DayPage/DayPageView.swift            # MODIFY — refresh/flip interaction; ensure .task re-runs don't strand a flip
WeeklyPlanner/Features/WeekPage/WeekPageView.swift          # MODIFY — apply selected weekOffset; refresh on offset change
WeeklyPlanner/Features/WeekPage/WeekPageViewModel.swift     # MODIFY — reload for the active offset (no stale per-offset cache)
WeeklyPlanner/Features/WeekPicker/WeekPickerSheet.swift     # MODIFY — confirm pick → setWeek wiring
WeeklyPlanner/Features/DayPage/TodayChip.swift              # REVIEW — everyMinute tick must not disturb flip state
WeeklyPlanner/Navigation/AppShell.swift                     # REVIEW — notification fan-out / refresh re-entrancy
WeeklyPlanner/Features/Settings/ConnectionRow.swift         # MODIFY — clarify Google Calendar "Coming soon" is non-actionable (suggestion 5 stop-gap)
WeeklyPlannerUITests/WeekNavigationStabilityUITests.swift   # NEW — drive navigation across the 1-minute tick
WeeklyPlannerTests/DayPage/PageFlipControllerTests.swift    # MODIFY — commit/cancel invariants, no-stuck-isFlipping
```

## Behavior Checklist
- [ ] Swiping left/right on the Week view changes the week every time, with no
      dead state after extended idling.
- [ ] Top-bar chevrons and Day-view week chevrons change the week reliably.
- [ ] Side-tab day selection always flips to that day.
- [ ] Picking a week in the Week Picker navigates to that week **and** shows
      that week's events (not the previous week's) — suggestion 22.
- [ ] After the app sits on a page for >2 minutes (past the first
      `.everyMinute` tick), all of the above still work without relaunch.
- [ ] Day view can always change date — it is never collaterally frozen by the
      Week view's state.

## Logic & Data Checklist
- [ ] `PageFlipController` can never be left with `target != nil` after an
      animation that has visually completed. Either the controller owns a
      fallback timeout that force-commits, or the view's commit scheduling is
      guaranteed to fire (and to survive `.task`/identity churn).
- [ ] `cancel()` is invoked on any interruption (gesture cancel, view
      disappear, mid-flip rebuild) so a partial flip can't strand the state.
- [ ] Week-picker selection routes to `setWeek(_:)` (or an equivalent
      offset-applying path) and the Week page reloads data for the new offset.
- [ ] No notification feedback loop: a store-change refresh must not re-post
      `.eventStoreDidChange` / `.taskStoreDidChange`.
- [ ] `TimelineView(.everyMinute)` updates are scoped to the time label only;
      they must not invalidate the flip controller or cancel its commit.

## Tests (TDD)
`PageFlipControllerTests`
- [ ] `testFlipThenCommitClearsTarget()` — after commit, `isFlipping == false`.
- [ ] `testInterruptedFlipCancels()` — a cancel resets `target`/`direction`.
- [ ] `testRapidFlipsNeverStrandIsFlipping()` — N queued flips all resolve.
- [ ] `testSetWeekAppliesOffset()` — `setWeek(3)` moves `current.week` to 3.

`WeekNavigationStabilityUITests` (UI)
- [ ] `testWeekSwipeStillWorksAfterIdle()` — open Week, wait past the
      one-minute tick (advance via a test seam or real wait), swipe → week
      changes.
- [ ] `testWeekPickerShowsSelectedWeeksEvents()` — pick a non-current week →
      asserts an event known to that week is visible.
- [ ] `testDayDateChangesAfterWeekViewIdle()` — the cross-view freeze guard.

## Acceptance Criteria
- The freeze is reproduced, root-caused (documented in the PR), and fixed —
  not merely papered over with a longer animation or a retry.
- All Behavior + Logic checklist items pass.
- New stability UI tests are green; full suite stays green.
- Verified on-device: navigate Week + Day for >3 minutes of mixed idle and
  interaction with no relaunch needed.

## Out of Scope
- Sticky-note swipe interaction — that's Phase 28.
- Building actual Google Calendar sync — Phase 37 (this phase only makes the
  disabled row unambiguous so testers stop filing suggestion 5).
- Real-time `AsyncStream` store observation (still deferred; refresh stays
  notification-driven).

## Risks & Notes
- **Don't fix by disabling the timeline.** `TodayChip`'s live time is a
  feature; the fix is to decouple flip state from view rebuilds, not to remove
  the tick.
- The one-minute reproduction makes manual testing slow; the UI test needs a
  way to fast-forward or tolerate the wait. A `TimelineSchedule` seam or an
  injected clock is preferable to a literal 60-second sleep.
- This phase and Phase 28 both touch the flip subsystem — land 27 first.
