# Phase 44 — Typography & Paper Expansion

> **Milestone P — Feedback Round 2** · items #58, #59, #62, #77, #78, #79
> Triage: `docs/superpowers/specs/2026-07-07-feedback-round-2-roadmap-design.md`
> Implementation plan: `docs/superpowers/plans/2026-07-07-phase-44-typography-paper-expansion.md`

## Goal

Text can actually get big (two new size tiers, and headers that ignored the
size setting now scale), the date under the day-of-week is larger, there are
more fonts and — for the first time — selectable paper templates (blank,
dot grid, grid, in addition to the current ruled look), and Settings gets
leaner: the Theme picker is removed and "Handwriting" becomes a "Font"
section.

## Prerequisites

- Phase 36a (fonts/templates groundwork). ✅
- Phase 42 recommended first (both touch `PaperEventSheet` — 42 restructures,
  this phase only rescales; re-grep anchors after 42 lands).

## Interpretation locked in triage (decision 5 — veto point)

Feedback #77 "Remove theme, handwriting connections" is implemented as:
**remove the Theme cards section** (app ships the Cream theme; `PaperTheme`
machinery stays internally) and **retitle/keep the font picker** (more fonts,
clearer "Font" name). The **Connections section stays** (Google Calendar
import is in active use).

## Current state (from 2026-07-07 exploration)

- `PaperSize` has 3 cases — scales 0.90 / 1.00 / 1.14; "Large" is only 14%
  bigger than medium, which is why "large" reads small (#58/#79).
- `DayPageHeader`'s date caption is fixed 12 pt Cochin-Italic and does not
  scale (#62); `WeekPageHeader` title is fixed 30 pt and does not scale.
- **No paper-template system exists** — `RuledLines` + `RedMarginLine` are
  copy-pasted into 6 views; templates are greenfield (#59/#78).
- 8 handwriting fonts exist; adding one = TTF in `Resources/Fonts/` +
  `Info.plist` `UIAppFonts` + `PaperFont` case + test-count updates.

## Files

- Modify: `WeeklyPlanner/DesignSystem/PaperSize.swift` (add `.xl`, `.xxl`)
- Modify: `WeeklyPlanner/Features/Settings/SizeSegmented.swift` (5 segments)
- Modify: `WeeklyPlanner/Features/DayPage/DayPageHeader.swift` (bigger, scaled caption)
- Modify: `WeeklyPlanner/Features/WeekPage/WeekPageHeader.swift` (+ other fixed-size
  headers found by sweep) (scale with `paperSize`)
- Create: `WeeklyPlanner/DesignSystem/PaperTemplate.swift`,
  `WeeklyPlanner/DesignSystem/Primitives/DotGrid.swift`,
  `WeeklyPlanner/DesignSystem/Primitives/GridLines.swift`,
  `WeeklyPlanner/DesignSystem/Primitives/PaperBackground.swift`
- Modify: the 6 ruling sites (`DayPageView`, `WeekPageView`, `PaperSettingsView`,
  `PaperNotesView`, `PaperReviewView`*, `AISearchPaperSheet`) → `PaperBackground`
  (*skip if Phase 45 already deleted Review)
- Modify: `WeeklyPlanner/Models/UserSettings.swift` (`templateKey`),
  `WeeklyPlanner/DesignSystem/Environment+Paper.swift` (`paperTemplate` entry),
  `WeeklyPlanner/Navigation/AppShell.swift` (resolve + inject)
- Add: 4 font families (6 TTF files — two families ship a real Bold) under
  `WeeklyPlanner/Resources/Fonts/` + `Supporting/Info.plist` `UIAppFonts` +
  `WeeklyPlanner/DesignSystem/PaperFont.swift` cases + OFL license texts
  under `licenses/`
- Modify: `WeeklyPlanner/Features/Settings/PaperSettingsView.swift` (drop Theme
  section; "Handwriting" → "Font"; add "Paper" section),
  `SettingsViewModel.swift` (template accessor), new `PaperCardsGrid.swift`
- Delete: `WeeklyPlanner/Features/Settings/ThemeCardsGrid.swift`, `ThemeCard.swift`
- Tests: see implementation plan.

## Visual & Interaction Checklist

- [ ] Text size offers **S / M / L / XL / XXL** (scales 0.90 / 1.00 / 1.14 /
  1.32 / 1.50); switching updates live (#58/#79).
- [ ] Day-page date caption ("12 May") is 16 pt × scale — clearly bigger,
  and grows with the size setting (#62).
- [ ] Week-page header (and any other fixed-size page header found by the
  sweep) scales with the size setting (#58).
- [ ] Settings shows **Font** (12 cards) and **Paper** (4 template cards:
  Ruled, Blank, Dot grid, Grid) sections; **no Theme section** (#77/#78/#59).
- [ ] Choosing Blank/Dot grid/Grid changes every paper page (Day, Week,
  Notes, Settings, Ask-the-Planner sheet) and hides the red margin line on
  non-ruled templates; Ruled reproduces today's look pixel-for-pixel.
- [ ] 4 new fonts render in the picker with live preview cards and apply
  app-wide (#78).

## Logic & Data Checklist

- [ ] `UserSettings.templateKey` persists ("ruled" default; lightweight
  migration); typed accessor mirrors `paperFont`.
- [ ] `themeKey` remains stored (compat) but no UI writes it; resolved theme
  is always `.cream` going forward — existing kraft/midnight users are
  migrated to cream on first launch of this build.
- [ ] Every new font's PostScript name verified via `UIFont` registration
  test (names can differ from filenames).

## Tests (TDD)

Unit: `PaperSizeTests` (new scales), `PaperTemplateTests` (new),
`PaperFontRegistrationTests` (count 8→12 + new PS names),
`PaperSettingsViewTests` (section/count guards updated),
`SettingsViewModelTests` (template persistence + theme migration),
`TypographyTests` (scaled-header pins).
UI: `SettingsUITests`-style smoke: switch size to XXL → day header grows;
switch paper to Dot grid → ruled lines absent (structure assertions via a11y ids).

## Acceptance Criteria

- Checklists pass; full unit suite green.
- Side-by-side: Ruled template at size M is pixel-identical to pre-phase
  screenshots (regression guard for the refactor).

## Out of Scope

- Deleting the `PaperTheme` type or its tokens (all views keep reading
  `theme.*`; only the picker goes).
- User-imported fonts or paper images.
- Week-start row changes (Phase 36b owns that row).

## Risks & Notes

- The 6 ruling sites are copy-pasted ZStacks — unifying them into
  `PaperBackground` is the one structural refactor here; do it first and
  screenshot-compare before adding new templates.
- XXL (1.50×) will stress layouts tuned for 1.14 — the sweep task includes
  a layout pass on Day/Week/sheet at XXL; `minHeight` floors from Phase 34
  lessons apply to sparse pages.
- New fonts must be OFL-licensed (Google Fonts); license texts go in
  `licenses/` (repo convention); README font-licensing note (`README.md`
  bottom) must be updated.
