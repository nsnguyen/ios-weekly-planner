# Phase 12 — Paper AI Search Overlay (UI Only)

## Goal
Build the slide-down Apple Intelligence overlay — leather chrome top bar, paper sheet inside with hand-written input, suggested queries, ink-shimmer "thinking" indicator, answer area with citation chips, quick actions, and "Answered on-device" footer. **AI responses in this phase are stubbed** with the canned answers from `data.jsx`; Phase 13 wires Foundation Models.

## Why this is needed
This is the AI front door. Wiring the UI first keeps Phase 13 focused on the model integration with a real surface to render into.

## Prerequisites
- Phases 02, 03, 05 (`InkShimmerText`, `PaperPillButton`).
- Phase 06 (event lookups for citations).

## Files Created / Modified

```
WeeklyPlanner/Features/AISearch/PaperAISearchView.swift            # NEW — root overlay
WeeklyPlanner/Features/AISearch/AISearchTopBar.swift               # NEW — chrome bar with title + Close
WeeklyPlanner/Features/AISearch/AISearchPaperSheet.swift           # NEW — paper sheet inner
WeeklyPlanner/Features/AISearch/AskInputField.swift                # NEW — handwriting input with mic icon
WeeklyPlanner/Features/AISearch/SuggestionList.swift               # NEW — list of pre-baked queries
WeeklyPlanner/Features/AISearch/ThinkingIndicator.swift            # NEW — ink-shimmer "thinking…"
WeeklyPlanner/Features/AISearch/AnswerBlock.swift                  # NEW — Q line + handwritten A + citations + actions
WeeklyPlanner/Features/AISearch/CitationChip.swift                 # NEW — yellow dashed chip
WeeklyPlanner/Features/AISearch/QuickActionPill.swift              # NEW — outline blue-ink pill
WeeklyPlanner/Features/AISearch/AISearchViewModel.swift            # NEW — query state, stub answers
WeeklyPlannerTests/Features/AISearchViewModelTests.swift           # NEW
WeeklyPlannerTests/Features/AISearchSnapshotTests.swift            # NEW
```

## Visual & Interaction Checklist

### Root overlay
- [ ] Full-bleed over the app, z-index 200, background = `theme.bookCover`.
- [ ] Animation: `aiSlide` 0.32s `cubic-bezier(0.2, 0.8, 0.2, 1)` translateY -30 → 0.
- [ ] Overflow hidden.

### `AISearchTopBar` (status-bar-respecting padding `54 16 10`)
- [ ] Flex row align-center justify-space-between, color `theme.chromeText`.
- [ ] Left:
  - Eyebrow `"ASK THE PLANNER"` — system 10pt weight 700 letter-spacing 1.6 opacity 0.65 uppercase.
  - Title `"Apple Intelligence"` — handwriting 24pt, text-shadow `0 1 2 rgba(0,0,0,0.4)`.
- [ ] Right: secondary `PaperPillButton` `"Close"` — 0.5pt border `chromeMuted`, bg `rgba(255,255,255,0.06)`, text `chromeText`.

### `AISearchPaperSheet` (`flex: 1, margin: 0 18 18 26`)
- [ ] Wraps the inner paper card with the same book-spine + edge-stripes + binding-shadow chrome as the Day Page (reuse `BookPage` from Phase 05).
- [ ] Red margin + 3 hole punches inside.

#### Input area (padding `18 18 8 44`, z-index 1)
- [ ] Eyebrow row: system 9pt weight 700 letter-spacing 1.6 color `ink3` + small sparkles 10pt + `"ASK"`, marginBottom 4.
- [ ] Underlined input:
  - Border-bottom 1pt `theme.ink3`, paddingBottom 4.
  - `AskInputField`: handwriting 22pt, `blueInk`, transparent background, no border, placeholder `"What's on Friday afternoon?"` in `ink3`.
  - Trailing mic icon 16pt `ink3` — taps → triggers Speech framework (Phase 13). For Phase 12 it's a static button; tap shows a toast `"Voice input coming soon"`.

#### Body (flex 1 scroll, padding `6 18 20 44`, z-index 1)

Three states:

##### State A — no answer, no thinking
- [ ] Heading `"Try asking"` — handwriting 18pt weight 700, color `ink`, marginTop 8, marginBottom 6, **wavy underline** in `rgba(26,26,42,0.25)`.
- [ ] `SuggestionList`: each item a tappable button, padding `5pt vertical`, transparent bg.
  - Content: handwriting 18pt, `blueInk`, line-height 1.2, text starts with `"↳ "`.
  - Suggestions from `data.jsx AI_SUGGESTIONS`:
    1. `"What's on my plate Friday afternoon?"`
    2. `"When's my next dentist appointment?"`
    3. `"Find a free 30-min slot tomorrow morning"`
    4. `"Any unconfirmed events in my inbox?"`
    5. `"When did I last meet with Sara?"`
    6. `"Summarize my week so far"`
- [ ] Footer microcopy (system 10pt italic color `ink3`, marginTop 18): `"On-device · your week stays private."`.

##### State B — thinking
- [ ] PaddingTop 30.
- [ ] `ThinkingIndicator` — handwriting 22pt weight 600 + `InkShimmerText` gradient (blueInk → redInk → greenInk → blueInk) animating 2.5s linear infinite.
- [ ] Body label: handwriting 16pt color `ink3` marginTop 8 `"flipping through your pages"`.

##### State C — answered
- [ ] Padding-top 8.
- [ ] Q line: handwriting 16pt italic color `ink2` `"Q · {query}"` marginBottom 6.
- [ ] A line: handwriting 22pt weight 600 color `blueInk` line-height 1.3 letter-spacing 0.1 — the answer text.
- [ ] **Citation chips** (if `answer.cites.count > 0`): flex-wrap row gap 6 marginTop 12:
  - Each `CitationChip`:
    - Inline-flex align-center gap 6, padding `4 8`, border 0.5pt dashed `ink3`, radius 2pt, background `rgba(255,230,128,0.4)` (yellow tint).
    - 6×6 category dot.
    - Handwriting 15pt title color `ink` line-height 1.
    - System 10pt color `ink3` `"{weekdayLong} {timeShort}"`.
  - Tap → closes overlay (`aiSlide` reverse 0.32s) then opens the event sheet for that ID.
- [ ] **Quick actions** (if `answer.actions.count > 0`): flex-wrap row gap 6 marginTop 12:
  - Each `QuickActionPill`: border 1pt `blueInk`, transparent bg, color `blueInk`, padding `4 11`, radius 999, system 11pt weight 600.
- [ ] Footer microcopy `"Answered on-device · 0.3s"` (system 9pt italic color `ink3` marginTop 18).

### Page corner curl (z-index 7)
- [ ] 28×28 bottom-right corner-curl gradient (same recipe as DayPage).

## Logic & Data Checklist

### `AISearchViewModel`
- [ ] State: `query: String = ""`, `thinking: Bool = false`, `answer: AIAnswer?`.
- [ ] `ask(suggestion: String)` sets `query`, `thinking = true`, schedules a 1.1s delay (to match the mock's feel), then sets `answer` from the stub map:
  - Contains `"dentist"` → `AI_ANSWERS.dentist`.
  - Contains `"free"` → `AI_ANSWERS.free`.
  - Contains `"inbox"|"email"|"unconfirmed"` → `AI_ANSWERS.inbox`.
  - Else → generic `"Based on your week, here's what I found."`.
- [ ] `clear()` resets to State A.
- [ ] In Phase 13, this view model gets a `useFoundationModels: Bool` flag. When true, call into the new `IntelligenceService`. Stub stays as fallback when AI disabled in Settings.

### Input behavior
- [ ] On appear, focus the input after 250ms (matches mock `setTimeout`).
- [ ] Enter key submits the typed query via `ask`.
- [ ] While `thinking`, input remains visible but pointer-events disabled.

### Citation tap routing
- [ ] Callback closes overlay first, then 100ms later requests the host to open the event detail sheet (to avoid two-modal-at-once).

## Tests (TDD)

`AISearchViewModelTests`
- [ ] `testAskDentistMapsToDentistAnswer()`.
- [ ] `testAskFreeMapsToFreeAnswer()`.
- [ ] `testGenericQueryReturnsFallbackAnswer()`.
- [ ] `testThinkingFlagSetThenClearedAfterDelay()`.

`AISearchSnapshotTests`
- [ ] State A (suggestions visible) — cream theme.
- [ ] State B (thinking) — captured at progress 0.5 of shimmer.
- [ ] State C (dentist answer with two citation chips) — both kraft and midnight themes.

## Acceptance Criteria
- Tapping the AI button in BookTopBar opens the overlay with the correct slide animation.
- Suggestions are tappable; selecting one transitions through thinking → answered states.
- Citation chip taps close the overlay and open the matching event detail sheet.
- Pull-to-dismiss: dragging the top bar down > 100pt dismisses with reverse animation.
- All animations honor reduce-motion (no shimmer; instant transitions).

## Out of Scope
- Real Foundation Models response generation (Phase 13).
- Voice input via Speech framework (defer to v1.1 or Phase 13 stretch).
- Streaming token-by-token rendering (Phase 13).

## Risks & Notes
- **InkShimmerText** must run cheaply — implement via `TimelineView(.animation(minimumInterval: 0.016))` with a gradient mask animating its `unitPoint`. Avoid `Animation.repeatForever` plus state — it can stutter.
- **Citation chip positioning** within `flex-wrap` translates to `FlowLayout` or `WrappingHStack`. iOS 16+: use the new `Layout` protocol to author a flow layout.
- **Mic icon hit area** must be ≥ 44×44 even though the icon is 16×16.
- The "1.1s thinking" delay should be replaced in Phase 13 with **actual** model inference time. Don't ship the fake delay to production.
