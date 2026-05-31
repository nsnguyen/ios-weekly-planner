# Phase 32 — AI Surfaces & Review Cleanup

> **Milestone L (v1.1 Polish).** Post-submission. Covers `docs/suggestions.md`
> line 38 (un-removable mock AI in Review) and line 49 (drop the "Apple
> Intelligence" name in favor of "Ask the planner").

## Goal
Stop showing canned/placeholder "AI" content as if it were real, and rename
the AI surface from "Apple Intelligence" to the product-native "Ask the
planner" everywhere it's user-visible.

## Why this is needed
- **(38)** The Review page renders hardcoded content that reads as broken or
  fake and can't be dismissed: a hardcoded "Morning run" streak
  (`ReviewViewModel`, `StreaksBlock`) and "design placeholder" summary bullets
  (`WeekSummaryGenerator` canned fallback shown via `ReviewSummaryBlock` /
  `AINotesList`). When real AI output isn't available, the page should degrade
  honestly — not display fabricated data the user can't clear.
- **(49)** "Apple Intelligence" leaks Apple's framework branding into the UX
  (`PaperSettingsView.swift:85` toggle, `AISearchTopBar.swift:48` title, plus
  accessibility labels in `AskInputField` / `AISearchTopBar`). The user wants
  the planner's own voice: "Ask the planner."

## Prerequisites
- Phase 13 (Foundation Models), Phase 14 (Review page). *(Shipped.)*

## Files Created / Modified

```
WeeklyPlanner/Features/Review/ReviewViewModel.swift          # MODIFY — drop hardcoded "Morning run" streak; honest empty state (38)
WeeklyPlanner/Features/Review/StreaksBlock.swift             # MODIFY — render real streaks or hide; no canned row (38)
WeeklyPlanner/Features/Review/ReviewSummaryBlock.swift       # MODIFY — show summary only when real; else honest fallback (38)
WeeklyPlanner/Features/Review/AINotesList.swift              # MODIFY — no placeholder bullets when AI unavailable (38)
WeeklyPlanner/Intelligence/Tasks/WeekSummaryGenerator.swift  # REVIEW — separate "real fallback message" from "design placeholder bullets" (38)
WeeklyPlanner/Features/Settings/PaperSettingsView.swift      # MODIFY — toggle label "Apple Intelligence" → "Ask the planner" (49)
WeeklyPlanner/Features/AISearch/AISearchTopBar.swift         # MODIFY — title + a11y label rename (49)
WeeklyPlanner/Features/AISearch/AskInputField.swift          # MODIFY — a11y label "Ask Apple Intelligence" → "Ask the planner" (49)
WeeklyPlanner/Features/AISearch/AnswerBlock.swift            # REVIEW — fallback wording references (49)
WeeklyPlanner/Resources/Localizable.xcstrings               # MODIFY — string updates for the rename (49)
WeeklyPlannerTests/Review/ReviewViewModelTests.swift        # MODIFY — no canned streak; empty state asserted
WeeklyPlannerTests/AISearch/AISearchTopBarTests.swift       # NEW/MODIFY — title reads "Ask the planner"
```

## Visual & Interaction Checklist
- [ ] **(38)** With no real AI summary/streak available, the Review page does
      **not** show the hardcoded "Morning run" streak or placeholder bullets;
      it shows an honest empty/disabled state (e.g., "Turn on Ask the planner
      for a weekly summary" or simply omits the block).
- [ ] **(38)** When real AI output **is** available, Review shows it normally.
- [ ] **(49)** Settings → Preferences toggle reads **"Ask the planner"** (not
      "Apple Intelligence").
- [ ] **(49)** The AI overlay top bar title reads **"Ask the planner"**.
- [ ] **(49)** All VoiceOver labels referencing "Apple Intelligence" are
      updated.

## Logic & Data Checklist
- [ ] Distinguish three Review states cleanly: real AI content, AI-off/honest
      fallback, and genuinely-empty week. None of them fabricate streaks/notes.
- [ ] The rename is **UX copy only** — the underlying framework is still
      Foundation Models; do not rename code symbols/subsystems
      (`com.weeklyplanner.WeeklyPlanner`, `PlannerLanguageModel`, etc.).
- [ ] App Store / reviewer notes that mention "Apple Intelligence" as a device
      requirement stay accurate (the *requirement* is real even if the in-app
      *name* changes) — flag for Phase 25 copy.
- [ ] No dangling references to the removed canned streak in tests or previews.

## Tests (TDD)
- [ ] `ReviewViewModelTests` — asserts no hardcoded "Morning run"; empty-state
      path returns no fabricated notes/streaks.
- [ ] `AISearchTopBarTests` — title string is "Ask the planner".
- [ ] A settings test asserts the toggle label changed.
- [ ] Phase 21 accessibility audits still pass with the new labels.

## Acceptance Criteria
- Review never shows un-removable fake AI content.
- "Apple Intelligence" no longer appears in user-facing UI; "Ask the planner"
  does, consistently.
- Full suite green; screenshot diff for Review + AI overlay approved.

## Out of Scope
- Building real streak tracking (user-defined habits) — that's a later phase;
  here we only stop faking it.
- Changing AI behavior, prompts, or model wiring.
- Renaming internal subsystems / log categories.

## Risks & Notes
- Decide the empty-Review treatment with the user: hide the block entirely vs.
  show a one-line "enable Ask the planner" prompt. Default: show the prompt
  when AI is off, hide when on-but-empty.
- "Ask the planner" must be applied uniformly — grep for "Apple Intelligence"
  across `Features/` before closing the phase; several a11y labels are easy to
  miss.
