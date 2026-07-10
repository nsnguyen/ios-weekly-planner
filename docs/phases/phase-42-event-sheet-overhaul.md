# Phase 42 — Event Sheet Overhaul

> **Milestone P — Feedback Round 2** · items #63, #67, #68, #69, #70, #71
> Triage: `docs/superpowers/specs/2026-07-07-feedback-round-2-roadmap-design.md`
> Implementation plan: `docs/superpowers/plans/2026-07-07-phase-42-event-sheet-overhaul.md`

## Goal

The add/edit event sheet becomes legible and self-explanatory: a properly
sized header ("Add New Event" / Cancel / Save), no hairlines crossing the
form rows, user-editable quick-add template chips, discoverable repeat
presets (including "Every 2 weeks"), and the Ask-AI affordance removed from
the event sheets entirely.

## Prerequisites

- Phase 35 (Repeating Events) — `Recurrence`, `RecurrenceRow` exist. ✅
- Phase 22 (Manual Event CRUD) — `PaperEventSheet` modes. ✅
- Recommended after Phase 45 lands (independent; ordering per triage spec).

## Files

- Modify: `WeeklyPlanner/Features/EventDetail/PaperEventSheet+Edit.swift` (header)
- Modify: `WeeklyPlanner/Features/EventDetail/EditableFields/PaperDateTimeRow.swift`,
  `CategorySwatchRow.swift`, `RecurrenceRow.swift`, `LocationField.swift`,
  `NotesField.swift` (remove bottom hairlines; recurrence presets)
- Create: `WeeklyPlanner/Models/RecurrencePreset.swift`
- Create: `WeeklyPlanner/Models/EventTemplateRecord.swift`,
  `WeeklyPlanner/Stores/EventTemplateStore.swift`
- Modify: `WeeklyPlanner/Models/EventTemplate.swift`, `WeeklyPlanner/Models/UserSettings.swift`
- Modify: `WeeklyPlanner/Features/EventDetail/EditableFields/TemplateChipsRow.swift`
- Create: `WeeklyPlanner/Features/EventDetail/EditableFields/TemplateEditorSheet.swift`
- Delete: `WeeklyPlanner/Features/EventDetail/EventAISticky.swift`,
  `EventAISuggestion.swift`, `WeeklyPlanner/Intelligence/Tasks/EventSuggestionGenerator.swift`
- Modify: `WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift`,
  `EventDetailViewModel.swift` (Ask-AI removal)
- Modify: `WeeklyPlanner/Stores/Environment+Stores.swift`,
  `WeeklyPlanner/Navigation/AppShell.swift`, `WeeklyPlanner/WeeklyPlannerApp.swift` (template store wiring)
- Modify: `WeeklyPlanner/Accessibility/AccessibilityIDs.swift`
- Tests: see implementation plan (unit + UI).

## Visual & Interaction Checklist

- [ ] Create-mode header title reads **"Add New Event"**; edit-mode reads
  **"Edit Event"** (#70).
- [ ] Header row is visually dominant: title 19pt·semibold, Cancel/Save
  17pt (× text-size scale) — bigger than every field row below (#70).
- [ ] No 0.5-pt hairline crosses the Starts / Ends / Category / Repeat /
  Location / Notes rows (#69). Row spacing alone separates fields.
- [ ] Template chips row shows the user's own chips; a trailing **Edit**
  chip opens a manager where chips can be added and deleted (#68).
- [ ] Repeat row's menu offers: None, Daily, Weekly, **Every 2 weeks**,
  Monthly, Yearly, **Custom…** — Custom reveals the existing
  interval stepper (already-built "Every N …" line) (#71).
- [ ] No "Ask AI" button or AI-suggestion sticky anywhere in the event
  sheets — view, edit, or create mode (#63, #67).

## Logic & Data Checklist

- [ ] Quick-add templates persist in SwiftData (`EventTemplateRecord`);
  curated defaults (gym, standup, lunch, call, errands, datenight) seed
  exactly once (guarded by `UserSettings.eventTemplatesSeeded`); deleting
  all chips is a legal, durable state.
- [ ] `RecurrencePreset → Recurrence` mapping is pure and unit-tested
  ("Every 2 weeks" = `.weekly, interval: 2`).
- [ ] `EventDetailViewModel` no longer holds `aiSuggestion` /
  `refreshAISuggestion`; `IntelligenceService` itself is untouched (still
  used by Ask-the-Planner).

## Tests (TDD)

Unit: `EventTemplateStoreTests` (new), `RecurrencePresetTests` (new),
`EventTemplateTests` / `EventDetailViewModelTests` (updated).
UI: `EventCreateFlowUITests` (updated copy assertions),
`TemplateEditorUITests` (new), `RepeatingEventUITests` (updated menu labels).

## Acceptance Criteria

- All checklists above pass; full unit suite green; the three UI suites green.
- Grep proof: no references to `EventAISticky`, `EventAISuggestion`,
  `EventSuggestionGenerator`, `paperEventSheet.askAI` outside git history.

## Out of Scope

- Sheet typography rescale beyond the header (Phase 44 does the global pass).
- AI sticky notes on the day page (Phase 43).
- Gmail "AI-suggested" inbox events (different feature; untouched).

## Risks & Notes

- `RepeatingEventUITests` drives Menu buttons **by label** ("Daily") — new
  menu items are additive, but do not rename existing labels.
- Phase 44 re-scales sheet fonts afterward; it must re-grep anchors in
  `PaperEventSheet+Edit.swift` since this phase moves them.
