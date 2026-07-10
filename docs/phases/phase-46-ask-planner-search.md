# Phase 46 — Ask the Planner: Search Overhaul

> **Milestone P — Feedback Round 2** · items #81, #82, #83
> Triage: `docs/superpowers/specs/2026-07-07-feedback-round-2-roadmap-design.md`
> Implementation plan: `docs/superpowers/plans/2026-07-07-phase-46-ask-planner-search.md`

## Goal

Asking the planner a question actually searches everything the user wrote —
calendar events, to-dos, free-text annotations, and Notes-tab notes; a new
literal keyword mode ("swim" → everything containing swim) works even
without Apple Intelligence; and the "Answered on-device · N s" footer is
gone.

## Prerequisites

- Phase 33 (Notes tab), Phase 34 (annotations) — the content being indexed. ✅
- Best sequenced last in Milestone P (45 settles what content exists; 43
  settles sticky text).

## Root causes being fixed (from 2026-07-07 exploration)

1. **"Not searching everything":** retrieval is Foundation-Models
   tool-calling over exactly five tools that query events, tasks, and Gmail
   inbox only. **No tool can reach annotations or notes** — `ToolRegistry`
   is constructed with three stores; the system prompt advertises only those
   five capabilities. Event keyword matching also covers `title` only (not
   `location`/`notes`).
2. **"Not working when I ask":** on any device without Apple Intelligence
   (or with it off), `StubIntelligenceService` answers from a **hardcoded
   canned table** (`AISearchCannedData`) that never touches user content.
3. **Footer:** `AnswerBlock` renders `"Answered on-device · N.Ns"` from
   `AIAnswer.elapsedSeconds`.

## Design

- **One shared retrieval core:** a new `KeywordSearchService` (pure, store-
  backed, unit-testable) does case-insensitive matching across: event
  title/location/notes, task title/reminderText, annotation text, note
  title/body — over a bounded window (default ±8 weeks for dated content;
  notes are undated and always searched).
- **LLM path:** a new `FoundationSearchPlannerTool` ("searchPlanner")
  wraps the same service, registered alongside the five existing tools;
  `ToolRegistry` gains annotation + note stores; the system prompt's
  capability list is extended so the model knows it can search everything.
- **Keyword mode (#82):** a "Find a word" affordance at the bottom of the
  Ask sheet switches the input to literal mode — results render as a
  grouped list (Events / To-dos / Notes / Free text) with day context;
  event rows navigate via the existing citation tap path. Works with AI off.
- **Fallback fix:** `StubIntelligenceService` stops returning canned prose
  for content questions — it returns real `KeywordSearchService` results
  formatted as a factual answer, so the feature "works" on every device.
- **Footer removal (#83):** delete the elapsed/on-device line and the
  `elapsedSeconds` plumbing; the availability fallback message stays.

## Files

- Create: `WeeklyPlanner/Intelligence/KeywordSearchService.swift`
- Modify: `WeeklyPlanner/Stores/AnnotationStore.swift` (`allAnnotations()`),
  `WeeklyPlanner/Stores/EventStore.swift` (match location+notes),
  `WeeklyPlanner/Stores/TaskStore.swift` (`tasks(inWeekOffsets:)` or fetch-all)
- Create: `WeeklyPlanner/Intelligence/Tools/SearchPlannerTool.swift` (+ FM
  adapter in `FoundationModelTools.swift`)
- Modify: `WeeklyPlanner/Intelligence/Tools/ToolRegistry.swift`,
  `WeeklyPlanner/Intelligence/PlannerLanguageModel.swift`,
  `WeeklyPlanner/Intelligence/SystemPrompt.swift`,
  `WeeklyPlanner/Navigation/AppShell.swift` (registry wiring)
- Modify: `WeeklyPlanner/Intelligence/StubIntelligenceService.swift`
  (content-backed fallback), `WeeklyPlanner/Features/AISearch/AISearchModels.swift`
  (retire canned data for content questions; drop `elapsedSeconds`)
- Modify: `WeeklyPlanner/Features/AISearch/AnswerBlock.swift` (footer),
  `AISearchViewModel.swift` (keyword mode + drop elapsed),
  `AISearchPaperSheet.swift` (mode toggle + results list)
- Create: `WeeklyPlanner/Features/AISearch/KeywordResultsList.swift`
- Modify: `WeeklyPlanner/Accessibility/AccessibilityIDs.swift`
- Tests: see implementation plan.

## Visual & Interaction Checklist

- [ ] Asking "what do I have about swim?" surfaces the swim event AND the
  swim to-do AND a note/annotation mentioning swim (#81).
- [ ] "Find a word" pill at the sheet bottom switches to literal mode;
  typing "swim" lists every match grouped by kind with its day; tapping an
  event result navigates to it (#82).
- [ ] Keyword mode and question fallback both work with Apple Intelligence
  OFF — real content, no canned prose (#81 "not working").
- [ ] No "Answered on-device · N s" footer anywhere; availability messages
  (e.g. "turned off in Settings") still show (#83).

## Logic & Data Checklist

- [ ] `KeywordSearchService` matches case-insensitively across all eight
  text fields; dated content bounded to ±8 weeks; notes unbounded.
- [ ] `ToolRegistry` carries annotation + note stores; `searchPlanner` tool
  callable by the model; system prompt lists the new capability.
- [ ] `AIAnswer.elapsedSeconds` removed (or unused-and-deprecated) with all
  writers cleaned up.

## Tests (TDD)

Unit: `KeywordSearchServiceTests` (new — the core), `SearchPlannerToolTests`
(new), `ToolRegistryTests` (updated init), `StubIntelligenceServiceTests`
(content-backed fallback), `AISearchViewModelTests` (keyword mode + no
elapsed), `AnswerBlockCleanBodyTests` (footer gone), `SystemPromptTests`
(capability line), `AnnotationStoreTests`/`EventStoreTests` (new fetch/match
methods).
UI: `AskPlannerKeywordUITests` (new: open sheet → Find a word → "swim" →
grouped results).

## Acceptance Criteria

- Checklists pass; full unit suite green; new + existing AISearch UI green.
- Simulator (no Apple Intelligence): keyword search returns real content;
  asking a question returns a content-backed factual answer, not canned text.

## Out of Scope

- Semantic/vector search (literal + LLM-tool retrieval only).
- Searching Gmail bodies (inbox suggestions' titles only, as today).
- A system-wide search field outside the Ask sheet (the feedback offered
  placement flexibility; the sheet keeps it one surface).

## Risks & Notes

- FoundationModels tool-count/behavior: adding a sixth tool changes model
  tool-choice dynamics — the system-prompt grounding rule must explicitly
  route "what did I write/note about X" to `searchPlanner`. Test on-device.
- `AISearchCannedData` is load-bearing for existing `AISearchViewModelTests`
  — those tests are rewritten, not deleted, to pin the new content-backed
  behavior.
- Unbounded fetch-alls: bound event/task queries by the ±8-week window to
  keep SwiftData fetches cheap; notes/annotations are small tables.
