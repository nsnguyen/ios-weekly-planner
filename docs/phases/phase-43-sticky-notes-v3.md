# Phase 43 — Sticky Notes v3: Grounded & Movable

> **Milestone P — Feedback Round 2** · items #61, #66 (#72, #73 duplicates)
> Triage: `docs/superpowers/specs/2026-07-07-feedback-round-2-roadmap-design.md`
> Implementation plan: `docs/superpowers/plans/2026-07-07-phase-43-sticky-notes-v3.md`

## Goal

AI sticky notes only say things grounded in the day's real content (events,
to-dos, free-text annotations) and say nothing when the day is empty; the
text never cuts off mid-sentence; the sticky can be dragged anywhere on the
page; and users can create their own sticky notes and move them around.

## Prerequisites

- Phase 24 (AI Sticky v2) — orchestrator/generators. ✅
- Phase 34 (Free-Text Annotations) — unit-space drag + persistence patterns. ✅
- AI Sticky Notes remain **opt-in** (default off) — this phase does not
  change the 2026-05-28 decision. User-created stickies work regardless of
  the AI toggle.

## Root causes being fixed (from 2026-07-07 exploration)

1. **Random/irrelevant:** `DayContext` carries only `events` + `inbox` — the
   LLM generators literally cannot see to-dos or free text; the keyword
   prompt then invites invention from bare titles; and an unconditional
   encouragement **fallback** fires even for an empty day.
2. **Mid-sentence cutoff:** `KeywordInsightGenerator` does
   `String(d.text.prefix(60))`, `EncouragementInsightGenerator` does
   `.prefix(80)`; `PlannerContext.maxResponseTokens` exists but is never
   passed to the model as `GenerationOptions(maximumResponseTokens:)`.
3. **Immovable:** the sticky is a fixed `.overlay(alignment: .topTrailing)`
   slot; `AIInsight` has no position fields; the only drag is the
   swipe-to-cycle gesture.
4. **No user stickies:** no model, no store, no creation affordance.

## Files

- Modify: `WeeklyPlanner/Intelligence/InsightGenerator.swift` (`DayContext` gains
  `tasks`, `annotationTexts`, `hasContent`)
- Modify: `WeeklyPlanner/Intelligence/StickyOrchestrator.swift` (empty day → no
  sticky, no fallback; carry sticky position across regeneration)
- Modify: `WeeklyPlanner/Intelligence/Tasks/KeywordInsightGenerator.swift`,
  `EncouragementInsightGenerator.swift` (grounded prompts; sentence-safe clipping)
- Modify: `WeeklyPlanner/Intelligence/PlannerLanguageModel.swift` (apply
  `GenerationOptions(maximumResponseTokens:)`)
- Create: `WeeklyPlanner/Intelligence/String+SentenceClip.swift`
- Modify: `WeeklyPlanner/Models/AIInsight.swift` (`unitX`/`unitY` optional position)
- Create: `WeeklyPlanner/Models/UserStickyNote.swift`, `WeeklyPlanner/Stores/UserStickyStore.swift`
- Modify: `WeeklyPlanner/Stores/SwiftDataStack.swift`, `Environment+Stores.swift`,
  `WeeklyPlanner/WeeklyPlannerApp.swift`, `WeeklyPlanner/Navigation/AppShell.swift` (wiring)
- Modify: `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift` (context build,
  sticky position + user-sticky CRUD)
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift` (positionable sticky
  overlay, sticky-pad affordance, user-sticky layer)
- Modify: `WeeklyPlanner/Features/DayPage/AIStickyStack.swift` (reposition drag)
- Create: `WeeklyPlanner/Features/DayPage/UserStickyView.swift`
- Modify: `WeeklyPlanner/Accessibility/AccessibilityIDs.swift`
- Tests: see implementation plan.

## Visual & Interaction Checklist

- [ ] A day with no events, no to-dos, no free text, and no inbox
  suggestions shows **no AI sticky at all** (#61 "if nothing, don't be weird").
- [ ] AI sticky text always ends at a sentence boundary — never a mid-word
  chop (#61).
- [ ] Long-press-and-drag lifts the AI sticky and drops it anywhere on the
  page; position survives leaving/returning to the day and sticky
  regeneration (#61). Horizontal swipe still cycles the cascade.
- [ ] A small sticky-pad affordance on the day page creates a user sticky
  (editor focused immediately); tap edits; drag moves; committing empty
  text deletes it (#66).
- [ ] User stickies render with the same paper/tape look, work with the AI
  toggle off, and persist across launches (#66).
- [ ] Page-flip swipe stays suppressed during any sticky drag (existing
  `stickyDragActive` contract — Phase 28 regression guard).

## Logic & Data Checklist

- [ ] `DayContext.tasks` / `.annotationTexts` populated from the day's real
  stores; `appleIntelligenceEnabled` reflects the actual setting (today it
  is hardcoded `true`).
- [ ] `StickyOrchestrator.run` returns `[]` without invoking any generator
  (including fallback) when `!day.hasContent`.
- [ ] LLM prompts enumerate the day's items and forbid invention; keyword
  confidence gate retained.
- [ ] `maximumResponseTokens` actually applied on every
  `LanguageModelSession.respond` call.
- [ ] `AIInsight.unitX/unitY` migrate as optional (nil = legacy slot);
  cache key unchanged.
- [ ] `UserStickyNote` CRUD store posts change notifications; registered in
  the SwiftData schema.

## Tests (TDD)

Unit: `SentenceClipTests` (new), `DayContextContentTests` (new),
`StickyOrchestratorTests` (empty-day + position-carry cases added),
`KeywordInsightGeneratorTests` / `EncouragementInsightGeneratorTests`
(prompt content + no-invention instruction pins), `UserStickyStoreTests`
(new), `AIInsightV2MigrationTests` (position-nil case), `DayPageViewModelTests`
(context build + sticky CRUD).
UI: `AIStickyStackUITests` (regression), `StickySwipeUITests` (regression),
`UserStickyUITests` (new: create → type → drag → persists).

## Acceptance Criteria

- All checklists pass; full unit suite green; the three sticky UI suites green.
- On-device spot check: an empty day generates no sticky; a day with a
  to-do "buy milk" and event "Dentist 3pm" yields a sticky referencing only
  those; no sticky text ends mid-word.

## Out of Scope

- Changing the AI opt-in default (stays off).
- Sticky notes on the Week page (day page only, as today).
- Editing AI sticky text; AI sticky dismissal keeps its existing UX.

## Risks & Notes

- Position + free drag must not regress the Phase 28 swipe-lock fix — the
  plan reuses the same `stickyDragActive` gate and keeps the reposition
  drag gated behind a long-press so the cascade swipe stays primary.
- SwiftData lightweight migration: new optional fields on `AIInsight` and a
  new model are additive — property-level defaults required (Phase 18/24
  deviation lessons apply).
- FoundationModels `GenerationOptions` availability-gated under
  `#if canImport(FoundationModels)` like the existing session code.
