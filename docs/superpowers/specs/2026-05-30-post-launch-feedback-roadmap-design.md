# Post-Launch Feedback Roadmap — Design & Phase Decomposition

> **Date:** 2026-05-30
> **Source feedback:** `docs/suggestions.md` (TestFlight / post-v1.0.0 user notes)
> **Status:** approved decomposition — phase docs `27`–`39` derived from this.

## Context

v1.0.0 has been bumped and is in TestFlight, but Phase 25 (Final Polish)
and Phase 26 (App Store Submission) are still open. `docs/suggestions.md`
collects the first round of real-user feedback: a mix of **critical bugs**
(week view freezes, navigation dead, sticky note blocks swiping), **view
polish & copy** tweaks across Day/Week/Month/Review/Event-sheet, **new
features** (Notes tab, free-text annotations, repeating events, more
personalization, Google Calendar sync), and two **exploratory** asks
(localization, voice memos).

This document records how that flat list is sliced into focused phases,
the product decisions behind the slicing, and a line-by-line traceability
map so nothing in `suggestions.md` is silently dropped.

## Decisions (locked with the user 2026-05-30)

1. **Scope:** all four buckets become phases — critical bugs, view polish,
   new features, and (as outline stubs) the future/exploratory items.
2. **Granularity:** focused phases, one per area/feature, matching the
   existing "one phase = one mergeable milestone" convention.
3. **AI Sticky Notes:** keep them opt-in (the 2026-05-28 decision stands —
   see `[[ai-sticky-notes-opt-in]]`). Only fix the critical swipe-lock bug.
   Do **not** build modify/remove UI and do **not** remove the feature.
4. **Sequencing:** the critical-bug phases (27, 28) are submission blockers
   and join Milestone K *before* Phase 26. Everything else is v1.1, after
   submission.

### Baked-in calls (flagged for veto; approved)

- **#5 Google Calendar sync** is reclassified **bug → feature**. The row has
  always been "Coming soon, disabled" (Phase 17); nothing regressed. It
  becomes a v1.1 feature (Phase 37). A tiny copy fix to make the disabled
  state unambiguous rides along in Phase 27 so testers stop reporting it.
- **#3 / #24** (modify/remove an individual sticky) are **out of scope** per
  decision 3; recorded in Phase 28's Out-of-Scope.
- **#55** (turn off sticky notes) is **already satisfied** — opt-in shipped
  default-off on 2026-05-28.
- **#1** (logo / app name) folds into the existing Phase 25 (icon & brand).
- **Numbering:** existing committed docs 25/26 keep their numbers; new work
  is 27+ with explicit forward dependencies, rather than renumbering.

## Milestone structure

| Milestone | Theme | Phases | Gate |
|-----------|-------|--------|------|
| **K — Ship** *(expanded)* | Stabilize + submit | 25, **27**, **28**, 26 | 26 green only after 27 + 28 |
| **L — v1.1 Polish** | Surface tweaks & copy | 29, 30, 31, 32 | post-submission |
| **M — v1.1 Features** | Net-new capability | 33, 34, 35, 36, 37 | post-submission |
| **N — Future** | Exploratory (outline only) | 38, 39 | unscheduled |

Execution order inside Milestone K: Phase 25 (polish), Phase 27 + 28 (bug
fixes, any order) → **Phase 26 (submission) last**.

## Phase map

| # | Phase | Suggestions | One-line goal |
|---|-------|-------------|---------------|
| 27 | Week View Stability & Cross-View Navigation | 21, 22, 23 | Kill the stuck-`isFlipping` freeze; make week + day navigation reliable. |
| 28 | Sticky Note Swipe-Lock Fix | 4 | Reset `stickyDragActive` robustly so an enabled sticky never blocks page-flips. |
| 29 | Day Page & Event Sheet Polish | 7, 8, 9, 10, 13, 14, 15, 16 | Reclaim note space, drop footer date/week, arrows-only nav, sheet copy/legibility. |
| 30 | Week Page Polish | 25, 26, 27, 28, 29, 30 | Events-first week spread: drop counts/week label, bigger dates, side overflow. |
| 31 | Month Grid & Week-Picker Navigation | 33, 34, 35, 36 | Centered month/year, explicit month/year stepping, unbounded range, weekday layout. |
| 32 | AI Surfaces & Review Cleanup | 38, 49 | Remove canned "mock AI" content; rebrand "Apple Intelligence" → "Ask the planner". |
| 33 | Notes Tab | 18 | A fourth tab for free-form misc/goal notes, decoupled from any day. |
| 34 | Free-Text Annotations | 6 | Place/edit free text on a page with color + bold/style options. |
| 35 | Repeating Events | 46 | Recurrence rules on events, round-tripped through EventKit. |
| 36 | Personalization Expansion | 41, 42, 45, 47 | More templates/fonts, all-7 week-start options, polished "Make it yours" footer. |
| 37 | Google Calendar Sync | 5 | Real two-way Google Calendar sync behind the existing connections row. |
| 38 | Localization & Real Translations | 52 | (Outline) Ship actual translated languages on the Phase 21 i18n scaffold. |
| 39 | Voice Memos | 53 | (Outline) Capture and attach short voice notes. |

## Suggestion → phase traceability

Every non-blank line in `docs/suggestions.md`:

| Line(s) | Note | Lands in |
|---------|------|----------|
| 1 — Smart planner (need logo) | App name/logo | Phase 25 (existing) |
| 2 — "Daily view" | section header | — |
| 3 — can't modify/remove sticky | out of scope (decision 3) | Phase 28 (Out-of-Scope) |
| 4 — sticky blocks page swipe | critical | **Phase 28** |
| 5 — Google Calendar sync | reclassified → feature | **Phase 37** (+ copy fix in 27) |
| 6 — free text, color, bold | feature | **Phase 34** |
| 7 — move header up | polish | **Phase 29** |
| 8 — remove footer date | polish | **Phase 29** |
| 9 — remove week under day-of-week | polish | **Phase 29** |
| 10 — prev/next as arrows | polish | **Phase 29** |
| 12 — "Under add event" | section header | — |
| 13 — template less transparent | polish | **Phase 29** |
| 14 — "Tear out"→"Delete" | copy | **Phase 29** |
| 15 — bigger/colored sheet header | polish | **Phase 29** |
| 16 — move "AI suggested" under Ask AI | polish | **Phase 29** |
| 18 — Notes tab | feature | **Phase 33** |
| 20 — "Weekly view" | section header | — |
| 21 — freeze after ~1 min | critical | **Phase 27** |
| 22 — week-pick shows stale events | critical | **Phase 27** |
| 23 — swipe/arrows dead | critical | **Phase 27** |
| 24 — remove week sticky | out of scope (decision 3) | Phase 28 (Out-of-Scope) |
| 25 — use side for many events | polish | **Phase 30** |
| 26 — events-only (hide checklist) | polish | **Phase 30** |
| 27 — drop bottom date | polish | **Phase 30** |
| 28 — "—" → "none" | copy | **Phase 30** |
| 29 — remove event/task counts | polish | **Phase 30** |
| 30 — remove week, bigger dates | polish | **Phase 30** |
| 32 — "Monthly view" | section header | — |
| 33 — weekday layout, remove week | polish | **Phase 31** |
| 34 — center month/year | polish | **Phase 31** |
| 35 — change year/month | feature | **Phase 31** |
| 36 — navigate past ±2 months | feature | **Phase 31** |
| 38 — remove mock AI in Review | polish | **Phase 32** |
| 40 — "Misc" | section header | — |
| 41 — more templates | feature | **Phase 36** |
| 42 — more fonts | feature | **Phase 36** |
| 44 — "Preferences" | section header | — |
| 45 — more week-start options | feature | **Phase 36** |
| 46 — repeating events | feature | **Phase 35** |
| 47 — better "Make it yours" footer | polish | **Phase 36** |
| 49 — remove "Apple Intelligence" name | copy | **Phase 32** |
| 52 — change language | future | **Phase 38** (stub) |
| 53 — voice memo | future | **Phase 39** (stub) |
| 55 — turn off sticky note | already satisfied (default-off) | — |

## Cross-cutting risks & notes

- **Phases 27 + 28 share the page-flip subsystem** (`PageFlipController`,
  `HorizontalSwipeGesture`, `AIStickyStack`). Land 27 first; 28 builds on a
  known-good flip lifecycle. Both want a UI test that drives navigation past
  the one-minute `TimelineView(.everyMinute)` tick.
- **Implementation plans are not written here.** Per `docs/phases/README.md`,
  each phase's task-level plan (with code) is authored with
  `superpowers:writing-plans` when that phase begins execution. These docs
  are scope contracts only.
- **Feature phases (33–37)** add models/stores; keep them isolated behind the
  existing `@Environment` store seams and SwiftData `@Model` conventions so
  tests can inject stubs (see Phase 03 / Phase 13 patterns).
