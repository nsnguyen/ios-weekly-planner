# Phase 16 — Settings (Theme, Handwriting, Size, Preferences, About)

## Goal
Build the embedded Settings page (paper book on leather; **not** a sheet) hosting the Theme grid (3 cards), Handwriting font grid (4 cards), Text size segmented (S/M/L), Preferences section (week-starts-on, default reminder, AI toggle), and the centered italic About footer. Live-switching is fully wired through `SettingsStore` (Phase 03) and refreshes every visible view immediately.

## Why this is needed
This is the most user-touched configuration surface and validates the whole theme system.

## Prerequisites
- Phases 02 (theme registry), 03 (`SettingsStore`), 05 (`PaperToggle`), 15 (tab navigation).

## Files Created / Modified

```
WeeklyPlanner/Features/Settings/PaperSettingsView.swift             # NEW — root embedded settings view
WeeklyPlanner/Features/Settings/SettingsHeader.swift                # NEW — "Make it yours" + subtitle
WeeklyPlanner/Features/Settings/SectionTitle.swift                  # NEW — eyebrow + handwriting title
WeeklyPlanner/Features/Settings/ThemeCardsGrid.swift                # NEW — 3-column grid
WeeklyPlanner/Features/Settings/ThemeCard.swift                     # NEW — single theme preview card
WeeklyPlanner/Features/Settings/FontCardsGrid.swift                 # NEW — 2-column grid
WeeklyPlanner/Features/Settings/FontCard.swift                      # NEW — single font preview card
WeeklyPlanner/Features/Settings/SizeSegmented.swift                 # NEW — segmented S/M/L
WeeklyPlanner/Features/Settings/PreferencesGroup.swift              # NEW — preferences card
WeeklyPlanner/Features/Settings/PrefRow.swift                       # NEW — expandable preference row
WeeklyPlanner/Features/Settings/ToggleRow.swift                     # NEW — toggle preference row
WeeklyPlanner/Features/Settings/AboutFooter.swift                   # NEW — "The Planner · v1.0 · made with care"
WeeklyPlanner/Features/Settings/SettingsViewModel.swift             # NEW — load + bind + persist
WeeklyPlannerTests/Features/SettingsViewModelTests.swift            # NEW
WeeklyPlannerTests/Features/SettingsSnapshotTests.swift             # NEW
```

## Visual & Interaction Checklist

### Outer page chrome (matches calendar/review)
- [ ] Full BookCover background.
- [ ] Padding top `54 16 12 26` for chrome:
  - Eyebrow `"THE PLANNER"` (10pt 700 letter-spacing 1.6 opacity 0.65 uppercase color `chromeText`).
  - Title `"Settings"` (handwriting 26pt color `#FAF6E9` textShadow `0 1 2 rgba(0,0,0,0.4)` marginTop -1).
- [ ] `BookPage` body with red margin, holes, edge stripes, binding shadow.
- [ ] Bottom margin 92pt so the tab bar doesn't cover content.

### `SettingsHeader` (inside the paper page)
- [ ] Padding `14 18 4 32` (paddingLeading 32 to clear the red margin).
- [ ] Handwriting 30pt weight 700 color `ink` `"Make it yours"`.
- [ ] Subtitle Cochin italic 12pt color `ink2` padding `0 18 6` `"Theme, handwriting, connections."`.
- [ ] Below: 2pt gradient line — `linear-gradient(90deg, ink, ink 60%, transparent)` opacity 0.4, margin `6 18 8`.

### Body scroll (`flex 1`, padding `14 18 28`)

#### 1. Theme section
- [ ] `SectionTitle` eyebrow `"LOOK & FEEL"` + title `"Theme"`.
- [ ] `ThemeCardsGrid`: 3 columns, gap 8, marginBottom 14.
- [ ] Three `ThemeCard`s for `.cream | .kraft | .midnight`.

##### `ThemeCard`
- [ ] Border: 1.5pt `blueInk` if active, 0.5pt `theme.rule` otherwise.
- [ ] Background = `theme.cream` of THIS card's theme (so each card shows its own paper color).
- [ ] Border-radius 12. Padding `10 8 8`. minHeight 84.
- [ ] Active glow: `0 0 0 3 blueInk @ 22% alpha` outer shadow.
- [ ] Top-right corner: 30×30 swatch of THIS theme's `bookCover` gradient with `border-radius: 0 12 0 12`.
- [ ] Top-left: handwriting 26pt weight 700 color `theme.ink` `"Aa"`.
- [ ] Bottom-left:
  - Theme name (system 12pt 700 color `theme.ink`).
  - Tag (system 10pt color `theme.ink2`).
- [ ] If active: 16×16 blue-ink circle (top-left, top: 6, left: 6) with white check inside.

#### 2. Handwriting section
- [ ] `SectionTitle` `"Handwriting"` (no eyebrow).
- [ ] `FontCardsGrid`: 2 columns, gap 8, marginBottom 14.
- [ ] Four `FontCard`s for `.caveat | .architects | .kalam | .indie`.

##### `FontCard`
- [ ] Border: 1.5pt `blueInk` if active, 0.5pt `rule` else.
- [ ] Background `theme.creamHi`.
- [ ] Padding `10 12`. Cursor pointer.
- [ ] Flex row align-center gap 10.
- [ ] **Left "Aa" sample** (width 28, text-align center): handwriting font of THIS card, 26pt weight 700, color `theme.ink`.
- [ ] **Right label** (flex 1, ellipsis): same font, 15pt color `theme.ink`.
- [ ] Active: blue-ink check circle (16pt) on trailing.

#### 3. Text size section
- [ ] `SectionTitle` `"Text size"`.
- [ ] Segmented control: 3 buttons (`Small`, `Medium`, `Large`).
- [ ] Outer: padding 3, radius 10, border 0.5pt `rule`, background `rgba(0,0,0,0.04)`, marginBottom 18.
- [ ] Each segment flex 1, padding `7pt vertical`, radius 7.
- [ ] Active: background `theme.creamHi`, shadow `0 1 2 rgba(0,0,0,0.08), 0 0 0 0.5pt rule`.
- [ ] Label uses **the current handwriting font** at the segment's display size: `S=14, M=17, L=20` pt (gives an immediate preview).

#### 4. Connections section
- [ ] **Implemented in Phase 17.** This phase reserves the space below "Text size" but doesn't render real content. To avoid an empty-looking page, render a placeholder card with title `"Connections"` and subtitle `"Coming up next…"` that Phase 17 replaces.

#### 5. Preferences section
- [ ] `SectionTitle` `"Preferences"`.
- [ ] `PreferencesGroup`: background `theme.creamHi`, radius 14, border 0.5pt `rule`, overflow hidden, marginBottom 14.

##### `PrefRow` — Week starts on
- [ ] Label (system 14pt 500 color `ink`), value (system 14pt color `ink2`, e.g., `"Monday"`), chevron-down 10×10 stroked `ink3`.
- [ ] Tap → expands to a wrap-row of two options pills: `Monday`, `Sunday`.
- [ ] Option pill: padding `4 10`, radius 999, system 12pt weight 500. Active: 1pt `blueInk` border + `blueInk @10%` bg.
- [ ] Persists via `SettingsStore.weekStartsOnMonday`.

##### `PrefRow` — Default reminder
- [ ] Options: `None | 5 min | 15 min | 30 min | 1 hr`.
- [ ] Persists via `SettingsStore.defaultReminderMinutes` (0/5/15/30/60; nil for none).

##### `ToggleRow` — Apple Intelligence
- [ ] Label `"Apple Intelligence"`, detail `"On-device only · keeps data private"` (system 11pt color `ink2`).
- [ ] `PaperToggle` (44×26).
- [ ] When off, AI features disabled across the app (Phase 13's `appleIntelligenceEnabled`).

#### 6. `AboutFooter`
- [ ] Centered italic handwriting 16pt color `ink3`: `"The Planner · v1.0 · made with care"`.
- [ ] Padding `10pt vertical`.

## Logic & Data Checklist

### Live switching
- [ ] Selecting a theme/font/size calls `SettingsStore.update { settings in ... }`. The store emits via its publisher.
- [ ] Every view reads `@Environment(\.paperTheme)` etc. — the environment is re-injected at `AppShell` based on the latest settings, so all child views re-render.
- [ ] No app reload required.

### Defaults
- [ ] Theme `.cream`, Font `.caveat`, Size `.m`, weekStartsOnMonday `true`, defaultReminder `15`, AI `on`.

### Performance
- [ ] Switching theme triggers `applyPaperTheme(...)` which is an O(1) struct swap; no expensive operations.
- [ ] FontCard previews load lazily (`.task` block) to avoid blocking the scroll.

## Tests (TDD)

`SettingsViewModelTests`
- [ ] `testSelectingThemePersists()`.
- [ ] `testSelectingFontUpdatesEnvironment()`.
- [ ] `testSelectingSizeChangesScaleFactor()`.
- [ ] `testTogglingAIDisablesIntelligenceService()`.
- [ ] `testDefaultsAfterFreshInstall()`.

`SettingsSnapshotTests`
- [ ] Snapshot of the full Settings page in cream (default state).
- [ ] Snapshot after switching to kraft + Architects font + Large size.
- [ ] Snapshot in midnight theme.

## Acceptance Criteria
- Tapping any theme card immediately flips the entire app's appearance (book cover, page, ink, text).
- Tapping a font card changes the handwriting font everywhere within ~200ms.
- Tapping S/M/L resizes handwriting content (date numbers grow visibly).
- Preferences persist across launches.
- Disabling AI hides the sparkles button and degrades to canned answers.

## Out of Scope
- Connections (Phase 17).
- Custom user colors / palettes (out of scope for v1.0).
- iCloud sync of settings (deferred).

## Risks & Notes
- **Live font swap** can cause layout shifts on long titles. Verify all screens visually after font switch.
- **Size L (1.14×)** stretches the date number to ~70pt; ensure header doesn't overflow.
- **PrefRow expand/collapse** animation should be 0.22s ease.
- **Settings inside the book** must paint correctly with paper texture; verify the gradient + ruled lines aren't obscured by the white preference cards.
