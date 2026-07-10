# Feedback Round 2 — Design & Phase Decomposition

> **Date:** 2026-07-07
> **Source feedback:** `docs/suggestions-round-2.md` (items #56–#85)
> **Status:** approved decomposition — phase docs `42`–`46` derived from this.
> **Prior art:** `2026-05-30-post-launch-feedback-roadmap-design.md` (round 1 → phases 27–39).

## Context

Round-2 user feedback on the current `main` build (post-Phase-37a). The mix:
**event-sheet UX complaints** (header hierarchy, ruling lines through form
rows, opaque Ask-AI affordance, fixed quick-add chips, coarse recurrence),
**AI quality complaints** (sticky notes hallucinate, truncate mid-sentence,
can't be moved; Ask-the-Planner doesn't retrieve the user's real content),
**readability** (fonts too small at max size, small day-header date, disliked
college-ruled paper), **simplification** (remove Review tab, blank empty
days, duplicate month header, leaner Settings), and **reinforcement of
already-planned work** (week-start options, logo, language, voice memos).

## Decisions (2026-07-07)

1. **Five new phases (42–46), Milestone P — Feedback Round 2.** Same
   convention as round 1: one phase = one mergeable milestone.
2. **Ask AI is removed from both event sheets** (#63 add + detail — user
   explicitly asked for removal on tap-event and questioned its purpose on
   add-event; grounding it was the alternative, removal is the cleaner call
   given a grounded sticky pipeline ships in Phase 43). The Gmail
   "AI-suggested" inbox events are a different feature and are untouched.
3. **AI sticky generation becomes grounded-or-silent** (#61): prompts are
   built ONLY from that day's real content (events, to-dos, free-text
   annotations); when the day has no content, no sticky is generated — no
   filler, no invented suggestions ("order uber" class bugs). Truncation is
   fixed at both ends (generation token budget + UI clipping).
4. **User-created sticky notes** (#66/#73) ship in the same phase as the AI
   sticky fixes (Phase 43) and both become movable, reusing the Phase 34
   annotation drag/persistence model where it fits.
5. **Settings simplification** (#77) — *interpretation flagged for veto*:
   "Remove theme, handwriting connections" is read as **remove the Theme
   picker and the Handwriting picker rows**. The **Connections** section
   (Gmail / Google Calendar) **stays** — Google Calendar import shipped in
   37a and is in active use; removing it would orphan sync. The Handwriting
   picker is not deleted outright but **replaced by a richer Fonts picker**
   (user simultaneously asks for *more* fonts, #78). The app keeps a single
   locked theme (the current default) internally; `PaperTheme` machinery is
   retained, only the picker UI is removed.
6. **Week-start feedback (#60/#64/#65/#80) is NOT a new phase.** It is
   exactly Phase 36b, whose full TDD plan already exists
   (`2026-06-04-phase-36b-week-start.md`: all seven days + the re-layout
   that makes tabs actually change). **36b is pulled forward: execute it
   first in this milestone.**
7. **"None" → blank (#75) reverses round-1 item #28** ("—" → "none"). The
   round-2 instruction wins; noted so nobody "fixes" it back.
8. **Review tab removal (#74) supersedes Phase 14/32 investment.** The
   feature code is deleted (not flag-hidden); git history and the
   `phase-20-archive`-style tag pattern preserve it if ever revived.
9. **Keyword search (#82)** lands inside the Ask-the-Planner overlay as a
   results-list mode (type → literal matches across all content; asking a
   question still routes to the LLM). One surface, two modes.

## Reinforced existing phases (no new docs)

| Item | Feedback | Already covered by |
|------|----------|--------------------|
| #56 | logo / app name | **Phase 40** (Final Polish, App Icon) |
| #60/#64/#65/#80 | week start options + tabs don't change | **Phase 36b** (plan ready: `docs/superpowers/plans/2026-06-04-phase-36b-week-start.md`) |
| #84 | change language | **Phase 38** (outline stub) |
| #85 | voice memo | **Phase 39** (outline stub) |

## Milestone structure

| Milestone | Theme | Phases | Gate |
|-----------|-------|--------|------|
| **P — Feedback Round 2** | Event sheet, AI quality, readability, simplification | **36b**, 42, 43, 44, 45, 46 | before Phase 40/41 (polish + submission stay the final two) |

**Recommended execution order:** 36b → 45 → 42 → 44 → 43 → 46.
Rationale: 36b is already planned (zero lead time); 45 deletes the Review
tab *before* 44's typography sweep (one less surface to restyle); 42 and 44
both touch `PaperEventSheet` (42 restructures, 44 only rescales — land the
restructure first); 43 builds on 34's annotation-drag patterns and is
independent; 46 spans every model so it goes last, after 43/45 settle what
content exists.

## Phase map

| # | Phase | Items | One-line goal |
|---|-------|-------|---------------|
| 42 | Event Sheet Overhaul | 63, 67, 68, 69, 70, 71 | Legible sheet header, no ruling through form rows, editable quick-add chips, custom repeat interval, Ask AI removed. |
| 43 | Sticky Notes v3 — Grounded & Movable | 61, 66, 72, 73 | AI sticky grounded in the day's real content or silent; no truncation; draggable; user-created stickies. |
| 44 | Typography & Paper Expansion | 58, 59, 62, 77, 78, 79 | Bigger sizes (incl. new XL tiers), bigger day-header date, more fonts + paper templates, leaner Settings (Theme/Handwriting pickers out, Fonts/Paper in). |
| 45 | Chrome & Navigation Simplification | 57, 74, 75, 76 | Review tab gone, blank empty week days, single month/year header, instant free-text entry. |
| 46 | Ask the Planner — Search Overhaul | 81, 82, 83 | Retrieval over ALL user content (events, to-dos, annotations, notes), literal keyword mode, no latency footer. |

## Item → phase traceability

Every item in `docs/suggestions-round-2.md`:

| Item | Note | Lands in |
|------|------|----------|
| 56 — logo | brand asset | Phase 40 (existing) |
| 57 — free-text tap too slow | interaction latency | **Phase 45** |
| 58 — font too small even on large | new size tiers | **Phase 44** |
| 59 — more templates | paper templates | **Phase 44** |
| 60 — week start doesn't change tabs | re-layout bug | **Phase 36b** (existing plan) |
| 61 — sticky random/truncated/immovable | AI quality | **Phase 43** |
| 62 — bigger date under day-of-week | day header | **Phase 44** |
| 63 — remove Ask AI on event tap | removal (decision 2) | **Phase 42** |
| 64 — only Sun/Mon options | 7-day picker | **Phase 36b** (existing plan) |
| 65 — change doesn't change tabs | same as 60 | **Phase 36b** (existing plan) |
| 66 — create own sticky + move | feature | **Phase 43** |
| 67 — Ask AI in add event weird ("order uber") | removal (decision 2) | **Phase 42** |
| 68 — editable quick buttons (gym, standup) | feature | **Phase 42** |
| 69 — line crossing Start/End/Category | sheet ruling | **Phase 42** |
| 70 — bigger header; "Add New Event" | hierarchy + copy | **Phase 42** |
| 71 — repeat frequency + custom (every 2 weeks) | recurrence UI | **Phase 42** |
| 72 — dup of 61 | — | Phase 43 |
| 73 — dup of 66 | — | Phase 43 |
| 74 — remove Review tab | deletion (decision 8) | **Phase 45** |
| 75 — blank instead of "None" | reverses round-1 #28 (decision 7) | **Phase 45** |
| 76 — duplicate month/year on top | dedupe headers | **Phase 45** |
| 77 — remove Theme, Handwriting | interpreted per decision 5 | **Phase 44** |
| 78 — more fonts + paper, no college-ruled | expansion | **Phase 44** |
| 79 — more font sizes | new tiers | **Phase 44** |
| 80 — week start beyond Sun/Mon | 7-day picker | **Phase 36b** (existing plan) |
| 81 — search everything / not working | retrieval overhaul | **Phase 46** |
| 82 — keyword search ("swim") | new mode (decision 9) | **Phase 46** |
| 83 — remove "on device · N s" | footer removal | **Phase 46** |
| 84 — language | future | Phase 38 (stub) |
| 85 — voice memo | future | Phase 39 (stub) |

## Cross-cutting risks & notes

- **42 vs 44 both edit `PaperEventSheet`** (42 restructures layout, 44
  rescales type). Sequenced 42-first; 44's plan must re-grep line anchors.
- **43 vs 45 both edit the Day page.** 45's free-text-latency change is
  small and localized to the annotation gesture; land 45 before 43 to keep
  43's diffs on a settled gesture base.
- **Removing the Review tab (45)** touches the tab enum, AppShell routing,
  notifications deep-links (if any target review), UI tests, and
  accessibility identifiers — the phase plan must sweep all references, not
  just hide the button.
- **44 keeps `PaperTheme` internally** (single locked theme). Deleting the
  type would ripple through every view; out of scope.
- **46 must define "everything":** events, tasks, free-text annotations
  (Phase 34), Notes tab (Phase 33), across a bounded date window with the
  question's parsed range taking precedence. The phase doc pins the corpus
  contract explicitly so "not working" is testable.
- **Implementation plans:** task-level TDD plans for 42–46 are authored
  with `superpowers:writing-plans` alongside this spec (same date prefix),
  since implementation is delegated (Cursor) and needs self-contained docs.
