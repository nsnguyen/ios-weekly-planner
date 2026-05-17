# Phase 13 — Foundation Models (Apple Intelligence) Integration

## Goal
Replace the stub answers in the AI overlay with real on-device responses from the **Foundation Models** framework (iOS 26+). The model has tool calls into our event/task/inbox stores so it can answer questions about the user's actual data, return citations to specific events, and propose actions. Also wire AI-generated sticky-note insights and review-page summaries.

## Why this is needed
The product's differentiator is "AI that actually knows your week." Without this, we're a pretty calendar.

## Prerequisites
- Phases 03 (stores to query), 04 (real event data), 06 (events list to cite), 11 (event sheet for citation targets), 12 (overlay UI).

## Files Created / Modified

```
WeeklyPlanner/Intelligence/IntelligenceService.swift              # NEW — protocol facade over FoundationModels
WeeklyPlanner/Intelligence/PlannerLanguageModel.swift             # NEW — concrete LanguageModelSession holder
WeeklyPlanner/Intelligence/SystemPrompt.swift                     # NEW — instructions + persona
WeeklyPlanner/Intelligence/Tools/FindEventsTool.swift             # NEW
WeeklyPlanner/Intelligence/Tools/FindFreeSlotsTool.swift          # NEW
WeeklyPlanner/Intelligence/Tools/ScanInboxTool.swift              # NEW
WeeklyPlanner/Intelligence/Tools/SummarizeWeekTool.swift          # NEW
WeeklyPlanner/Intelligence/Tools/LastInteractionTool.swift        # NEW (e.g. "when did I last meet with Sara")
WeeklyPlanner/Intelligence/Tools/ToolRegistry.swift               # NEW
WeeklyPlanner/Intelligence/AIAnswer.swift                         # NEW — typed answer struct (also used by Phase 12)
WeeklyPlanner/Intelligence/SafetyGuard.swift                      # NEW — content moderation pre/post
WeeklyPlanner/Intelligence/StreamingTokenAccumulator.swift        # NEW — for streaming UI
WeeklyPlanner/Intelligence/Tasks/StickyInsightGenerator.swift     # NEW — generates day AIInsight rows
WeeklyPlanner/Intelligence/Tasks/WeekSummaryGenerator.swift       # NEW — review page summary + bullets
WeeklyPlanner/Intelligence/Tasks/EventSuggestionGenerator.swift   # NEW — per-event AI sticky text
WeeklyPlanner/Intelligence/Availability.swift                     # NEW — checks model availability
WeeklyPlanner/Features/AISearch/AISearchViewModel.swift           # MODIFY — switch from stub to IntelligenceService
WeeklyPlannerTests/Intelligence/SystemPromptTests.swift           # NEW
WeeklyPlannerTests/Intelligence/ToolRegistryTests.swift           # NEW
WeeklyPlannerTests/Intelligence/IntelligenceServiceTests.swift    # NEW (mocked LanguageModelSession)
WeeklyPlannerTests/Intelligence/SafetyGuardTests.swift            # NEW
```

## Visual & Interaction Checklist

No new UI; this phase wires through to existing surfaces:
- [ ] AI overlay (Phase 12) now shows streamed tokens of the answer as they arrive.
- [ ] During streaming, the "thinking…" indicator transitions to a soft typewriter caret after the first token arrives.
- [ ] If the model isn't available (older device, disabled in Settings, or low battery), fall back to a clear message: `"Apple Intelligence is unavailable on this device. Showing canned suggestions."`.
- [ ] Per-event AI sticky text on the event sheet (Phase 11) is now sourced from `EventSuggestionGenerator` once the user opens an event; show a brief shimmer until ready (≤ 1s typical).
- [ ] Per-day AI sticky notes (Phase 07) now generated daily by `StickyInsightGenerator` at app launch or first view of the day.

## Logic & Data Checklist

### `IntelligenceService` (protocol)
- [ ] `func availability() async -> AvailabilityState` — checks `SystemLanguageModel.default.availability`.
- [ ] `func ask(_ query: String, context: PlannerContext) async throws -> AIAnswer`.
- [ ] `func streamAsk(_ query: String, context: PlannerContext) -> AsyncThrowingStream<AnswerDelta, Error>`.
- [ ] `func generateDayInsight(weekOffset: Int, dayIdx: Int) async throws -> AIInsight`.
- [ ] `func generateWeekSummary(weekOffset: Int) async throws -> WeekSummary`.
- [ ] `func generateEventSuggestion(eventID: UUID) async throws -> String`.

### `PlannerLanguageModel`
- [ ] Wraps `LanguageModelSession`. Singleton per app session; recreated when user toggles AI in Settings or theme changes (theme doesn't affect model — just the session reuse policy).
- [ ] Configured with our system prompt + registered tools.
- [ ] Use `Generation` mode `default` for balanced quality; `concise` for sticky notes.
- [ ] Token limit cap to keep responses snappy (e.g., 256 for the overlay; 120 for stickies).

### System prompt (`SystemPrompt.swift`)
- [ ] Persona: `"You are The Planner — a thoughtful assistant that lives inside the user's personal weekly journal."`.
- [ ] Style: handwriting-friendly tone; concise; no emojis except in streak/celebration contexts.
- [ ] Output contract: when answering with citations, **call `findEvents`** and use the result IDs in the response. The model should not fabricate event IDs.
- [ ] Privacy reminder: `"All processing is on-device. Do not invent or reference data the user has not provided."`.
- [ ] Capabilities list:
  - find events (by date, person, location, category)
  - find free slots
  - scan inbox suggestions
  - summarize weeks
  - identify last interaction with a person
- [ ] Refuse politely if asked to do things outside calendar/tasks (e.g., write code, jailbreak attempts) — `"I'm scoped to your planner."`.

### Tools (each conforms to `Tool` protocol)

**`FindEventsTool`**
- [ ] Parameters: `dateRange: ClosedRange<Date>?`, `categories: [Category]?`, `keywords: [String]?`, `personName: String?`.
- [ ] Calls `EventStore.events(matching:)` (extend in Phase 03 to accept a query struct).
- [ ] Returns `[ToolEventResult]` — `{ id, title, start, end, location, category, source }`.

**`FindFreeSlotsTool`**
- [ ] Parameters: `dateRange`, `minMinutes`, `dayPart: "morning" | "afternoon" | "evening" | "any"`.
- [ ] Returns up to 5 free slots as `{ start, end }`.

**`ScanInboxTool`**
- [ ] Parameters: `weekOffset: Int?`, `limit: Int = 10`.
- [ ] Returns pending `InboxSuggestion`s.

**`SummarizeWeekTool`**
- [ ] Parameters: `weekOffset: Int`.
- [ ] Returns aggregate `{ totalHoursByCategory, tasksDone, tasksOpen, highlights: [eventID] }`.

**`LastInteractionTool`**
- [ ] Parameters: `personName: String`.
- [ ] Searches event titles, locations, and (if Gmail connected) recent message subjects.
- [ ] Returns `{ eventID?, date, context }`.

### `AIAnswer` (typed)
- [ ] `query: String`, `intent: String`, `answerText: String`, `cites: [UUID]`, `inbox: [UUID]`, `actions: [String]`.

### Safety guard
- [ ] Pre-prompt sanitization: trim, length-cap 600 chars, strip control chars.
- [ ] Post-answer scan for PII leaks beyond the user's own data (model shouldn't add new PII).
- [ ] Always honor the `appleIntelligenceEnabled` setting — if false, never invoke the model.

### Streaming
- [ ] Use `Session.respond(to:)` streaming variant. Accumulate tokens, parse the answer envelope only at end-of-stream for structured fields like citations.
- [ ] If the model emits a tool call mid-stream, pause the visible stream, resolve the tool, continue.

### `StickyInsightGenerator`
- [ ] Trigger: app launch (background task) + when a day's events change.
- [ ] For each visible day in `[today-7, today+14]`, generate one short insight (≤ 80 chars) using the model. Use the schema: `text`, `colorHex (one of #FFE680, #C9F0E0, #FFCCC9)`, `tiltDegrees ∈ [-5, 5]`.
- [ ] Persist into `AIInsight` rows.

### `WeekSummaryGenerator`
- [ ] Triggered by Review page (Phase 14) on appear if no fresh summary for current week.
- [ ] Outputs `WeekSummary { headline, bullets: [(text, ink: blue|red|green)], completionPercent }`.

### `EventSuggestionGenerator`
- [ ] Triggered when event sheet opens (Phase 11).
- [ ] Context: the event + travel time + weather (skip weather in v1.0).
- [ ] Returns one sticky sentence ≤ 140 chars.

### Availability gating
- [ ] On launch, check `SystemLanguageModel.default.availability`:
  - `.available` → enable AI features.
  - `.unavailable(.deviceNotEligible)` → hide AI UI elements or show fallback.
  - `.unavailable(.modelNotReady)` → retry every 60s for up to 5 minutes; then degrade.
  - `.unavailable(.appleIntelligenceNotEnabled)` → show a one-time card prompting the user to enable in Settings.
- [ ] Document the device matrix in `README.md` (Phase 22).

## Tests (TDD)

`SystemPromptTests`
- [ ] `testPromptIncludesPersona()`.
- [ ] `testPromptListsAllToolsByName()`.

`ToolRegistryTests`
- [ ] `testFindEventsToolFiltersByCategory()` — feed in seed, call with `categories: [.health]`, expect 4 events.
- [ ] `testFindFreeSlotsReturnsExpectedMorningSlot()` — Sunday May 17 morning → 7:30–10:00 free slot (matches `AI_ANSWERS.free`).
- [ ] `testScanInboxReturnsPendingOnly()`.

`IntelligenceServiceTests` (mocked LanguageModelSession)
- [ ] `testAskDentistInvokesFindEventsTool()`.
- [ ] `testCitationsReturnedAreValidEventIDs()`.
- [ ] `testStreamingDeltasAccumulate()`.
- [ ] `testFallbackWhenModelUnavailable()` — returns canned `AIAnswer` from stub map.

`SafetyGuardTests`
- [ ] `testQueryLongerThan600CharsIsTrimmed()`.
- [ ] `testControlCharsStripped()`.
- [ ] `testAIDisabledShortCircuits()`.

## Acceptance Criteria
- On a real iPhone 15 Pro with Apple Intelligence on, asking `"When's my next dentist appointment?"` returns the correct event and Date/time within 2 seconds, with a citation chip linking to event `e4`.
- Sticky notes generated nightly look qualitatively similar to the seed insights from `paper-planner.jsx`.
- Disabling Apple Intelligence in Settings shows the fallback path immediately.
- All tests pass with mocked `LanguageModelSession`.

## Out of Scope
- Cloud-based fallback (no — privacy story is "on-device only").
- Voice input (defer to v1.1).
- Multilingual prompts (English only in v1.0; Phase 21 handles localization of static strings).

## Risks & Notes
- **Foundation Models API surface is iOS 26+ only.** Build the entire `IntelligenceService` behind a protocol so unit tests don't need the framework imported.
- **Streaming UX**: if first token doesn't arrive within 1.5s, switch from "thinking…" to a "still thinking…" frame to reassure user.
- **Token budgets**: keep prompts short; pre-summarize event data into compact JSON blocks before injecting.
- **Tool latencies**: tool calls hit SwiftData, which is fast but synchronous. Wrap each tool body with a 200ms timeout to fail soft.
- **Hallucination risk**: enforce that citation IDs returned must exist; if model returns an invalid ID, drop the citation chip.
- **Battery/thermals**: heavy AI use can throttle. Monitor `ProcessInfo.thermalState` and downgrade to canned answers when `.serious` or `.critical`.
