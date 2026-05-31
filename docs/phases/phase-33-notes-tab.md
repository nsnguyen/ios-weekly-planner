# Phase 33 — Notes Tab

> **Milestone M (v1.1 Features).** Post-submission. Covers `docs/suggestions.md`
> line 18: *"Add another tab for notes. Just misc notes they want to have for
> any day or for goals."*

## Goal
Add a fourth tab — **Notes** — a free-form space for miscellaneous notes and
goals that aren't tied to a specific day or event.

## Why this is needed
Today every text surface is bound to a day (events, tasks, the AI sticky).
Users want a durable scratch space for goals and standing notes that persists
independent of the calendar — a core planner expectation that's currently
missing.

## Prerequisites
- Phase 03 (SwiftData models/persistence), Phase 15 (Paper Tab Bar &
  `TabSelection`), Phase 16 (Settings paper page pattern). *(Shipped.)*

## Files Created / Modified

```
WeeklyPlanner/Models/Note.swift                          # NEW — @Model: id, title, body, kind (.misc/.goal), created/updated, optional dayKey
WeeklyPlanner/Stores/NoteStore.swift                     # NEW — NoteStoring protocol + SwiftDataNoteStore + StubNoteStore
WeeklyPlanner/Stores/Environment+Stores.swift            # MODIFY — \.noteStore environment key + stub default
WeeklyPlanner/Features/Notes/PaperNotesView.swift        # NEW — paper page hosting the notes list (book chrome, like Settings/Review)
WeeklyPlanner/Features/Notes/NotesListView.swift         # NEW — list of NoteRow; empty state
WeeklyPlanner/Features/Notes/NoteRow.swift               # NEW — single note preview row
WeeklyPlanner/Features/Notes/NoteEditorView.swift        # NEW — create/edit a note (ink text styling)
WeeklyPlanner/Features/Notes/NotesViewModel.swift        # NEW — @Observable: load/add/update/delete/reorder
WeeklyPlanner/Navigation/TabSelection.swift              # MODIFY — add .notes case
WeeklyPlanner/Navigation/PaperTabBar.swift               # MODIFY — render the 4th tab
WeeklyPlanner/Navigation/PaperTab.swift                  # MODIFY — Notes tab cell (icon + label + index-tab bookmark)
WeeklyPlanner/Navigation/AppShell.swift                  # MODIFY — route .notes to PaperNotesView
WeeklyPlanner/Models/UserSettings.swift                  # REVIEW — lastTabRaw must accept the new case
WeeklyPlanner/Stores/SwiftDataStack.swift                # MODIFY — register Note in the schema
WeeklyPlanner/Resources/Localizable.xcstrings            # MODIFY — Notes strings
WeeklyPlannerTests/Notes/NotesViewModelTests.swift       # NEW — CRUD + ordering
WeeklyPlannerTests/Notes/NoteStoreTests.swift            # NEW — persistence round-trip
WeeklyPlannerUITests/NotesTabUITests.swift               # NEW — add/edit/delete a note via the tab
```

## Visual & Interaction Checklist
- [ ] A fourth tab appears in `PaperTabBar` (Calendar / Review / **Notes** /
      Settings — confirm order with the mock/user) with the same leather index-
      tab bookmark treatment as existing tabs.
- [ ] Tapping Notes shows a paper page (book chrome consistent with Settings /
      Review) listing existing notes; an empty state invites the first note.
- [ ] A note can be created, opened, edited, and deleted; edits persist across
      relaunch and tab switches.
- [ ] Notes render in the paper aesthetic (handwriting ink, ruled lines) and
      respect the active theme/font/size.
- [ ] Notes can optionally be tagged as a "goal" vs a loose "misc" note (light
      distinction — confirm scope with user; default: a simple kind flag).

## Logic & Data Checklist
- [ ] `Note` is a SwiftData `@Model` registered in `SwiftDataStack`; CRUD goes
      through `NoteStoring` so previews/tests inject `StubNoteStore`.
- [ ] Notes are **not** tied to a day by default (`dayKey` optional, reserved
      for a future "note for a specific day" link).
- [ ] Tab selection persists via the existing `UserSettings.lastTabRaw`
      mechanism, extended for the new case.
- [ ] Store mutations post a `.noteStoreDidChange` notification (mirroring the
      event/task pattern) if any other surface needs to react; otherwise the
      VM refreshes locally.
- [ ] Accessibility: notes list + editor annotated per the Phase 21 patterns.

## Tests (TDD)
- [ ] `NoteStoreTests` — add → fetch → update → delete round-trips through
      SwiftData.
- [ ] `NotesViewModelTests` — ordering (most-recent or manual), empty state,
      edit persistence.
- [ ] `NotesTabUITests` — create a note, background/relaunch (or tab away/back),
      assert it persists.
- [ ] Accessibility audit on the Notes page.

## Acceptance Criteria
- A working Notes tab with persistent CRUD in the paper aesthetic.
- Tab order/labels match the agreed design; tab persistence works.
- Full suite green; screenshot of the Notes page approved.

## Out of Scope
- Rich text / attachments / checklists inside notes (free-text styling is
  Phase 34's concern; reuse its ink styling if it lands first).
- Syncing notes to EventKit/Reminders or any external service.
- Folders, tags beyond the misc/goal flag, or search (later if asked).

## Risks & Notes
- **Tab count:** four tabs is the comfortable max for the leather bar — confirm
  the icon set and ordering against `docs/mock/` before building. If a fifth
  tab is ever wanted, the bar layout needs rework (flag now).
- Decide with the user whether "goals" deserve a distinct sub-surface or are
  just notes with a flag. Default to the lighter flag approach (YAGNI).
- If Phase 34 (free-text annotations) ships first, share its ink text-styling
  component rather than duplicating it.
