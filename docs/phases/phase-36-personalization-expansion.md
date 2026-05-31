# Phase 36 — Personalization Expansion

> **Milestone M (v1.1 Features).** Post-submission. Covers `docs/suggestions.md`
> lines 41 (more templates), 42 (more fonts), 45 (more week-start options), and
> 47 (polish the "Make it yours" footer).

## Goal
Broaden "make it yours": more handwriting fonts, more page/quick-add templates,
more week-start options, and a more finished Settings footer.

## Why this is needed
Personalization is a headline feature of the paper aesthetic, and testers want
more of it. These are mostly additive (new assets/options) on top of the
Phase 16 Settings architecture — except week-start, which has a real ripple
(see Risks).

## Prerequisites
- Phase 02 (fonts/theme tokens), Phase 16 (Settings), Phase 03 (`UserSettings`).
  *(Shipped.)* Plus `WeekMath` for week-start.

## Files Created / Modified

```
# (42) Fonts
WeeklyPlanner/Resources/Fonts/                              # NEW — additional handwriting font files (+ project.yml registration)
WeeklyPlanner/DesignSystem/PaperFont.swift                 # MODIFY — register new font keys + size/weight mapping
WeeklyPlanner/Features/Settings/FontCardsGrid.swift        # MODIFY — render the new font cards
project.yml                                                # MODIFY — bundle new fonts (regenerate with XcodeGen)

# (41) Templates
WeeklyPlanner/Models/Template.swift                        # NEW/REVIEW — model the template set referenced by the add-event "continue with template" flow
WeeklyPlanner/Features/.../TemplatePicker.swift            # MODIFY — surface the expanded set (exact location TBD — see Risks)

# (45) Week start
WeeklyPlanner/Models/UserSettings.swift                    # MODIFY — weekStart accepts more than Sun/Mon
WeeklyPlanner/Features/Settings/PreferencesGroup.swift     # MODIFY — expanded week-start options
WeeklyPlanner/Stores/WeekMath.swift                        # MODIFY — parameterize the week-start day (currently Monday-based)

# (47) Footer
WeeklyPlanner/Features/Settings/AboutFooter.swift          # MODIFY — finished footer (version, links, polish)
WeeklyPlanner/Features/Settings/SettingsHeader.swift       # REVIEW — "Make it yours" header/footer cohesion

WeeklyPlanner/Resources/Localizable.xcstrings              # MODIFY — new option labels
WeeklyPlannerTests/Settings/SettingsViewModelTests.swift   # MODIFY — new font/template/week-start counts
WeeklyPlannerTests/Stores/WeekMathTests.swift              # MODIFY — week-start parameterization
```

## Visual & Interaction Checklist
- [ ] **(42)** The Fonts grid offers additional handwriting fonts beyond the
      current four (Caveat / Architects Daughter / Kalam / Indie Flower); each
      previews live and applies app-wide like the existing ones.
- [ ] **(41)** The template set (the "continue with template" add-event path)
      offers more choices; selecting one applies as before.
- [ ] **(45)** Week-start offers more than Sunday/Monday (target: all seven, or
      at least add Saturday) and changing it re-lays the Week page and picker
      consistently.
- [ ] **(47)** The Settings "Make it yours" footer reads as finished — app
      version, tasteful links (Privacy/Terms once they exist), centered italic
      treatment — not a placeholder.

## Logic & Data Checklist
- [ ] New fonts are bundled (project.yml/XcodeGen), registered in `PaperFont`,
      and covered by the same size/weight-for-legibility mapping (Phase 21).
- [ ] **Week-start is the one non-additive change:** `WeekMath` currently
      assumes a Monday-based calendar (`mondayCalendar()`, `PageCoordinate.day`
      0 = Mon). Supporting other start days must thread a configurable first
      weekday through `WeekMath`, the Week page rows, the side tabs, and the
      picker — without breaking offset math. Verify against the freeze fix
      (Phase 27) so nothing regresses.
- [ ] `UserSettings` persists the new selections; `SettingsViewModel`
      structural invariants (counts) updated.
- [ ] Template model/source confirmed (see Risks) before expanding it.

## Tests (TDD)
- [ ] `SettingsViewModelTests` — asserts the new font count, template count,
      and week-start option count.
- [ ] `WeekMathTests` — week construction correct for each supported start day
      (offsets, today-detection, ranges).
- [ ] A settings UI test flips a new font and a new week-start and asserts the
      app re-renders.

## Acceptance Criteria
- More fonts, templates, and week-start options are selectable and apply
  correctly; the footer is finished.
- Week-start change verified across Week page + picker + side tabs with correct
  math; full suite green.

## Out of Scope
- A custom font importer or user-uploaded templates (curated sets only).
- New themes (the three themes stay; this phase is fonts/templates/week-start/
  footer).

## Risks & Notes
- **Week-start (45) is deceptively large.** The whole app is Monday-anchored;
  arbitrary start days touch `WeekMath` and every week-aware surface. If it
  proves too big to ride alongside fonts/templates, **split it into its own
  phase** during `writing-plans` and ship the additive items first.
- **"Templates" (41) needs scoping.** Confirm what "template" refers to — the
  add-event "continue with template" flow (suggestion 13) is the known
  template surface; verify the model/source before expanding. Don't invent a
  new template system if an existing one just needs more entries.
- New fonts require license clearance for redistribution — verify before
  bundling.
