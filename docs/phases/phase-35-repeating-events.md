# Phase 35 — Repeating Events

> **Milestone M (v1.1 Features).** Post-submission. Covers `docs/suggestions.md`
> line 46: *"Repeating events."*

## Goal
Let users create events that recur (daily / weekly / monthly / yearly, with an
end condition), round-tripped through EventKit so recurrence behaves like a
native calendar event.

## Why this is needed
Recurring commitments (standups, gym, birthdays, rent) are table-stakes for a
planner. Phase 22 added manual event CRUD but single-occurrence only; users
must currently re-enter repeating items by hand.

## Prerequisites
- Phase 04 (EventKit integration), Phase 22 (Event CRUD / `EventComposerState`),
  Phase 11 (Event sheet). *(Shipped.)*

## Files Created / Modified

```
WeeklyPlanner/Models/Recurrence.swift                      # NEW — Recurrence value type: frequency, interval, end (never/onDate/afterCount)
WeeklyPlanner/Models/Event.swift                           # MODIFY — optional recurrence field + recurrence identity for EventKit
WeeklyPlanner/Stores/EventKit/RecurrenceMapper.swift       # NEW — Recurrence <-> EKRecurrenceRule
WeeklyPlanner/Stores/EventStore+EventKit.swift             # MODIFY — write/read recurrence on the EKEvent mirror
WeeklyPlanner/Stores/EventStore.swift                      # REVIEW — upsert/delete semantics for a series
WeeklyPlanner/Features/EventDetail/EventComposerState.swift            # MODIFY — draft recurrence; canSave/isDirty include it
WeeklyPlanner/Features/EventDetail/EditableFields/RecurrenceRow.swift  # NEW — paper-styled recurrence picker (freq + interval + end)
WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift          # MODIFY — host RecurrenceRow
WeeklyPlanner/Features/EventDetail/EventDetailViewModel.swift          # MODIFY — display recurrence in read mode
WeeklyPlanner/Notifications/EventNotificationScheduler.swift           # REVIEW — schedule reminders across occurrences sanely
WeeklyPlannerTests/Models/RecurrenceMapperTests.swift      # NEW — Recurrence <-> EKRecurrenceRule fidelity
WeeklyPlannerTests/EventDetail/RecurrenceComposerTests.swift # NEW — draft → build → round-trip
WeeklyPlannerUITests/RepeatingEventUITests.swift           # NEW — create a weekly event, see it on multiple days
```

## Visual & Interaction Checklist
- [ ] The event create/edit sheet has a **Repeat** row: None / Daily / Weekly /
      Monthly / Yearly, an interval ("every N"), and an end condition (never /
      on a date / after N times).
- [ ] A repeating event appears on each of its occurrences across the Day and
      Week views.
- [ ] Read mode shows a human-readable recurrence summary ("Every week on
      Mon", "Daily until Jun 30").
- [ ] Editing/deleting prompts for **this event vs. all future** where it
      matters (at minimum: deleting a series vs. one occurrence).
- [ ] Recurrence created in the app shows up correctly in the system Calendar
      (and vice-versa, read-only is acceptable for externally-created rules).

## Logic & Data Checklist
- [ ] `Recurrence` maps losslessly to/from `EKRecurrenceRule` for the supported
      frequencies + end conditions (`RecurrenceMapper`, fully unit-tested).
- [ ] The EventKit mirror is the source of truth for occurrence expansion —
      the app does not hand-roll an occurrence generator where EventKit can
      enumerate (use `EKEventStore` enumeration for the visible range).
- [ ] Editing a single occurrence vs. the series has defined semantics; v1 may
      restrict to series-level edits + single-occurrence delete (detachment)
      if full exception handling is too large — decide in `writing-plans` and
      state the limit.
- [ ] Reminder scheduling (Phase 19) does not explode across an unbounded
      series — schedule only for occurrences within a bounded forward window.
- [ ] Accept-from-Gmail (Phase 18) path is unaffected (those stay single events
      unless explicitly extended).

## Tests (TDD)
- [ ] `RecurrenceMapperTests` — each frequency + each end condition maps both
      ways; interval > 1 preserved.
- [ ] `RecurrenceComposerTests` — composer draft builds an Event with the right
      recurrence; isDirty detects recurrence changes.
- [ ] `RepeatingEventUITests` — create weekly event, navigate days/weeks,
      assert it appears on the right occurrences.

## Acceptance Criteria
- Users can create/edit/delete repeating events; occurrences render across
  views and round-trip through EventKit.
- Reminder count for a series stays bounded; full suite green.
- On-device: a weekly event created in-app appears in iOS Calendar with the
  correct rule.

## Out of Scope
- Complex RRULEs beyond freq + interval + simple end (e.g., "last weekday of
  month", multi-day BYDAY sets) — basic set first; extend on demand.
- Per-occurrence edits with full exception trees if scoped out above.
- Natural-language recurrence entry ("every other Tuesday" typed) — picker only.

## Risks & Notes
- **Occurrence semantics are the hard part.** Lean on EventKit's own
  enumeration and recurrence rules rather than building a parallel engine;
  define and document the this-vs-all-future edit policy explicitly.
- Reminders × recurrence is a fan-out trap — cap the scheduling window and
  reschedule forward as time advances (tie into the existing rescheduling
  observer).
- Validate the device round-trip early; `EKRecurrenceRule` edge cases (end-date
  inclusivity, count semantics) are easy to get subtly wrong.
