# Phase 21 — Accessibility, Dynamic Type, Localization, RTL

## Goal
Make the app usable by everyone: VoiceOver labels and hints on every interactive surface, Dynamic Type respected for system-font text, reduce-motion alternative animations, proper color contrast, full localization scaffolding (English shipped + ready for translation), and RTL-aware layouts.

## Why this is needed
Accessibility is non-negotiable for App Store approval and to honor users with disabilities. The paper aesthetic challenges Dynamic Type and contrast; we tackle that head-on here.

## Prerequisites
- All UI phases (05–20).

## Files Created / Modified

```
WeeklyPlanner/Accessibility/AccessibilityModifiers.swift            # NEW — common labels/hints
WeeklyPlanner/Accessibility/AccessibilityIDs.swift                  # NEW — string IDs for UI tests
WeeklyPlanner/Accessibility/DynamicTypeSupport.swift                # NEW — handwriting-font scale rules
WeeklyPlanner/Accessibility/ReduceMotionAnimations.swift            # NEW — reduce-motion variants
WeeklyPlanner/Resources/Localizable.xcstrings                       # NEW — String Catalog
WeeklyPlanner/Resources/InfoPlist.xcstrings                         # NEW — localized usage descriptions
WeeklyPlannerTests/Accessibility/AccessibilityAuditTests.swift      # NEW — uses Accessibility Audit API
WeeklyPlannerTests/Accessibility/LocalizationTests.swift            # NEW
WeeklyPlannerUITests/AccessibilityUITests.swift                     # NEW — VoiceOver smoke flows
```

## Visual & Interaction Checklist

### VoiceOver
- [ ] Every tap target has `accessibilityLabel` + `accessibilityHint` if action isn't obvious.
- [ ] DayPage events:
  - Label: `"{title}, {category}, {weekday} {timeRange}, location {location-or-'no location'}, source {Gmail | added by you}"`.
  - Hint: `"Double tap to open details."`.
- [ ] Side tabs: label `"{Weekday}, day {N} of 7"`. Hint: `"Double tap to flip to this day."`.
- [ ] Page-flip chevrons: `"Previous day"`/`"Next day"` etc.
- [ ] Today pill: `"Return to today"`.
- [ ] AI button: `"Apple Intelligence search"`. Hint: `"Double tap to ask about your week."`.
- [ ] Date range pill: `"Week of {range}, week {n}"`. Hint: `"Double tap to jump to a different week."`.
- [ ] Week picker day cells: full date `"{Weekday}, {Month} {day}, {year}"`. Today gets `"Today, "` prefix.
- [ ] Sticky note: label `"AI insight: {text}"`. Hint: `"Double tap to fold or expand."`.
- [ ] To-do checkboxes: `"{Task title}, {completed | not completed}"`. Action: toggle.
- [ ] Event sheet rows: each has its label.
- [ ] Tab bar tabs: standard `tab` traits.
- [ ] AI overlay input: label `"Ask Apple Intelligence"`. Trait: `.searchField`.
- [ ] Citation chips: `"{Event title}, {weekday} {time}. Double tap to open."`.

### Rotor categories
- [ ] Define a "Events" custom rotor on the Day Page so VoiceOver users can flick through events.
- [ ] Define a "Days" rotor when on the Week Page.

### Dynamic Type
- [ ] System-font text obeys `Font.body`, `.subheadline`, etc. with `.dynamicTypeSize(...)`.
- [ ] Handwriting-font text uses a **custom scale**:
  - `Font.custom("Caveat-SemiBold", size: 22, relativeTo: .body)`.
  - Cap maximum scale at `.xxxLarge` (handwriting fonts at AX5 look unreadable).
- [ ] When Dynamic Type is at AX2+:
  - Time gutter widens from 48 → 64pt.
  - Side tabs widen from 22 → 32pt to accommodate rotated text.
  - Tab bar labels truncate or hide (icon-only).
- [ ] Test the Day page at every Dynamic Type setting and adjust layouts.

### Reduce Motion
- [ ] When `@Environment(\.accessibilityReduceMotion)` is true:
  - Page flip → 0.15s opacity crossfade.
  - Sticky peel → instant toggle.
  - AI overlay slide → fade.
  - Ink shimmer → static gradient.
  - Tab bookmark cross-fade still allowed (it's brief).
- [ ] Document each substitution.

### Color contrast
- [ ] Audit every text/background pair against WCAG AA (4.5:1 for normal text, 3:1 for large text).
- [ ] Known risk: handwriting font in `ink3` (34% alpha) on cream is below 3:1. **Decision**: increase to 4:1 minimum for body text; reserve low-alpha for decorative-only (page-number footer, hole-punch shadows).
- [ ] Midnight theme: blueInk `#7DB0F2` on `#1E1F2D` ≈ 6.8:1 ✓.
- [ ] Kraft theme: ink `#3A2418` on cream `#E6D2A8` ≈ 7.4:1 ✓.
- [ ] Increase-contrast mode (`@Environment(\.legibilityWeight)`): swap thin handwriting weights for SemiBold/Bold variants.

### Smart Invert / Color Filters
- [ ] No need to support Smart Invert; the paper aesthetic is inherent. Test the Midnight theme as the "dark" alternative.

### Bold Text
- [ ] When `.boldText` is enabled, swap Caveat Regular → Caveat SemiBold; Kalam Light → Kalam Regular; etc.

### RTL
- [ ] Mirror layout via `.environment(\.layoutDirection, .rightToLeft)` for testing.
- [ ] Side tabs move to the right side. Red margin moves to the right. Hole punches on the right. Page curl on the bottom-left.
- [ ] Page flip direction inverts: drag right → next, drag left → previous.
- [ ] DayPageHeader giant date number rotates +3° (mirrored) — verify by test.
- [ ] Strings flow RTL natively when locale is Arabic/Hebrew.

### Localization scaffolding
- [ ] All user-facing strings extracted to `Localizable.xcstrings`.
- [ ] English (US) seeded. Translations deferred (post-v1.0); structure must be production-ready.
- [ ] Info.plist usage descriptions and other plist strings via `InfoPlist.xcstrings`.
- [ ] Numbers/dates use `Calendar.current` and `Date.FormatStyle` so locale-driven formatting works.
- [ ] Pluralization handled via `Localizable.stringsdict`-equivalent in xcstrings (`%@ events` vs `%@ event`).

## Logic & Data Checklist

### `DynamicTypeSupport`
- [ ] Helper: `Font.custom(_:size:relativeTo:)` wrappers per typography token.
- [ ] Layout adapter: returns adjusted `Spacing` constants based on Dynamic Type size.

### `ReduceMotionAnimations`
- [ ] `Animation.pageFlip(reduced: Bool)`, `.sheetSlide(reduced:)`, etc. Returns the appropriate reduced or full animation.

### `AccessibilityIDs`
- [ ] Stable string IDs for UI tests:
  - `"daypage.event.row.\(eventID)"`
  - `"daypage.todo.row.\(taskID)"`
  - `"weekpicker.weekrow.\(offset)"`
  - `"settings.theme.card.\(themeKey)"`
  - etc.

### Audit
- [ ] Use `XCAccessibilityAuditIssueType.all` in `AccessibilityAuditTests` to run automated audits on each screen.
- [ ] Expected baseline: 0 issues on light + dark with default Dynamic Type. Document known exceptions.

## Tests (TDD)

`AccessibilityAuditTests`
- [ ] `testDayPagePassesAudit()`.
- [ ] `testWeekPagePassesAudit()`.
- [ ] `testReviewPagePassesAudit()`.
- [ ] `testSettingsPagePassesAudit()`.
- [ ] `testAISearchOverlayPassesAudit()`.
- [ ] `testEventSheetPassesAudit()`.

`LocalizationTests`
- [ ] `testAllUserFacingStringsAreLocalized()` — heuristic: scan code for `Text(` literals; fail on hardcoded English.
- [ ] `testPluralsFormatCorrectly()`.

`AccessibilityUITests`
- [ ] `testVoiceOverOpensFirstEvent()`.
- [ ] `testRotorEventsIteratesAllEvents()`.

## Acceptance Criteria
- VoiceOver users can navigate Day, Week, Review, Settings, AI overlay, Event sheet, and complete all tasks (open event, toggle task, ask AI).
- App passes `XCAccessibilityAudit` for all phases except documented exceptions.
- App renders correctly at AX5 Dynamic Type (no clipping, no overlapping).
- Reduce Motion disables flips and shimmers as described.
- RTL layout mirrors correctly when set to Arabic/Hebrew.
- All strings live in xcstrings; no hardcoded user-facing English in code.

## Out of Scope
- Translations for non-English languages (scaffolding only).
- VoiceOver/AssistiveTouch deeper actions (custom rotors are added; gestures defer).
- Switch Control specific tuning (we get this for free with proper accessibility traits).

## Risks & Notes
- **Handwriting fonts and VoiceOver**: VoiceOver reads characters individually if font has unusual unicode mapping. Verify pronunciation of "Caveat" rendered text. Add `accessibilityValue` overrides where needed.
- **Page flip in reduced motion**: a 0.15s crossfade can still feel jarring; tune timing during testing.
- **Color contrast in low-light mode (Midnight)**: ink2 at 65% on `#1E1F2D` is barely enough; audit each token.
- **Page-curl + binding shadows** are decorative and should be `accessibilityHidden(true)`.
