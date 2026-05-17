# Phase 02 — Design System (Theme, Fonts, Tokens)

## Goal
Implement the complete paper-theme design system — three themes (Cream, Kraft, Midnight), four handwriting fonts, three text sizes, and the runtime mutation pipeline — accessible to every view via SwiftUI Environment. No views consume it yet; the system is the contract.

## Why this is needed
Every visual phase (05–17) reads colors and fonts from this system. Changes from Settings (Phase 16) must propagate instantly. Pixel-perfect parity with the mock depends on these tokens being exact.

## Prerequisites
- Phase 01.

## Files Created / Modified

```
WeeklyPlanner/DesignSystem/PaperTheme.swift                 # NEW — struct with all colors
WeeklyPlanner/DesignSystem/PaperThemeKey.swift              # NEW — enum: cream | kraft | midnight
WeeklyPlanner/DesignSystem/PaperFont.swift                  # NEW — enum: caveat | architects | kalam | indie
WeeklyPlanner/DesignSystem/PaperSize.swift                  # NEW — enum: s | m | l (scale 0.90 / 1.00 / 1.14)
WeeklyPlanner/DesignSystem/CategoryPalette.swift            # NEW — work/personal/health/family/focus/travel
WeeklyPlanner/DesignSystem/Typography.swift                 # NEW — type ramp (page weekday 30, date 62, etc.)
WeeklyPlanner/DesignSystem/Spacing.swift                    # NEW — insets, radii, page geometry
WeeklyPlanner/DesignSystem/AnimationTokens.swift            # NEW — durations + curves
WeeklyPlanner/DesignSystem/Environment+Paper.swift          # NEW — EnvironmentKey for PaperTheme
WeeklyPlanner/DesignSystem/Color+Hex.swift                  # NEW — Color(hex:) initializer
WeeklyPlanner/DesignSystem/View+InkColor.swift              # NEW — modifier that returns category-ink color
WeeklyPlannerTests/DesignSystem/PaperThemeTests.swift       # NEW
WeeklyPlannerTests/DesignSystem/CategoryPaletteTests.swift  # NEW
WeeklyPlannerTests/DesignSystem/TypographyTests.swift       # NEW
```

## Visual & Interaction Checklist

This phase has no UI. The tokens are the deliverable. Verification is done in Phase 05+ when primitives consume them.

## Logic & Data Checklist

### `PaperThemeKey` enum cases & exact values

Three themes. Every property below must be present on every theme. Values from `docs/mock/paper-theme.jsx`.

**Cream (default)** — keyed `.cream`, name `"Cream"`, tag `"Vintage notebook"`:
- [ ] `cream` = `#FAF6E9`, `creamHi` = `#FCF9EE`, `creamLo` = `#F1EAD2`
- [ ] `rule` = `rgba(139,121,80,0.18)`, `ruleSoft` = `rgba(139,121,80,0.08)`
- [ ] `redLine` = `rgba(192,72,72,0.55)`
- [ ] `ink` = `#1A1A2A`, `ink2` = `rgba(26,26,42,0.62)`, `ink3` = `rgba(26,26,42,0.34)`
- [ ] `blueInk` = `#1A3A7A`, `redInk` = `#9C2A2A`, `greenInk` = `#2C5A2C`, `pencil` = `#3A3A55`
- [ ] `bookCover` = linear-gradient(160°, `#2C2418` → `#1A1410`) — implement as `LinearGradient` with `startPoint`/`endPoint` derived from 160° (`startPoint: UnitPoint(x: sin(160°·...))` — provide a helper).
- [ ] `bookSpine` = `#0F0A06`
- [ ] `chromeText` = `#E8D9B7`, `chromeMuted` = `rgba(232,217,183,0.65)`
- [ ] `edgeStripe` = repeating-linear-gradient(180°, `#EFE5C9` 0–2px / `#E2D6B3` 2–4px) — implement as a `Canvas` or repeating `Rectangle`s.
- [ ] `holePunch` = `#E8E0CB`
- [ ] `paletteHero` = `#FAF6E9`, `paletteAccent` = `#1A1410` (used in Settings ThemeCard preview).

**Kraft** — keyed `.kraft`, name `"Kraft"`, tag `"Warm tan paper"`:
- [ ] `cream` `#E6D2A8`, `creamHi` `#EDD8B0`, `creamLo` `#D4BA85`
- [ ] `rule` `rgba(58,30,12,0.20)`, `ruleSoft` `rgba(58,30,12,0.10)`, `redLine` `rgba(160,48,32,0.50)`
- [ ] `ink` `#3A2418`, `ink2` `rgba(58,36,24,0.62)`, `ink3` `rgba(58,36,24,0.36)`
- [ ] `blueInk` `#23467A`, `redInk` `#A03020`, `greenInk` `#3A5A20`, `pencil` `#3A2418`
- [ ] `bookCover` gradient(160°, `#3A2010` → `#20120A`), `bookSpine` `#150C06`
- [ ] `chromeText` `#F3E5C0`, `chromeMuted` `rgba(243,229,192,0.65)`
- [ ] `edgeStripe` (`#D4BA85` 0–2 / `#BFA66E` 2–4), `holePunch` `#C8AE7D`
- [ ] `paletteHero` `#E6D2A8`, `paletteAccent` `#3A2010`

**Midnight** — keyed `.midnight`, name `"Midnight"`, tag `"For night use"`:
- [ ] `cream` `#1E1F2D`, `creamHi` `#252638`, `creamLo` `#181826`
- [ ] `rule` `rgba(220,220,240,0.13)`, `ruleSoft` `rgba(220,220,240,0.06)`, `redLine` `rgba(240,128,128,0.40)`
- [ ] `ink` `#EAE6D9`, `ink2` `rgba(234,230,217,0.65)`, `ink3` `rgba(234,230,217,0.36)`
- [ ] `blueInk` `#7DB0F2`, `redInk` `#F08080`, `greenInk` `#88D680`, `pencil` `#EAE6D9`
- [ ] `bookCover` gradient(160°, `#0A0814` → `#04040C`), `bookSpine` `#000004`
- [ ] `chromeText` `#B0B0C2`, `chromeMuted` `rgba(176,176,194,0.6)`
- [ ] `edgeStripe` (`#2A2B40` 0–2 / `#1F2030` 2–4), `holePunch` `#2A2A38`
- [ ] `paletteHero` `#1E1F2D`, `paletteAccent` `#7DB0F2`

### `PaperFont` enum

- [ ] `.caveat` — PostScript name `Caveat-Regular` (and Medium/SemiBold/Bold variants), display label `"Caveat"`, fallback `"Cochin"`.
- [ ] `.architects` — `ArchitectsDaughter-Regular`, label `"Architects"`, fallback `"Caveat"`.
- [ ] `.kalam` — `Kalam-Light`/`-Regular`/`-Bold`, label `"Kalam"`, fallback `"Caveat"`.
- [ ] `.indie` — `IndieFlower`, label `"Indie"`, fallback `"Caveat"`.
- [ ] Each case exposes `.font(at: CGFloat, weight: Font.Weight) -> Font` using `Font.custom(_:size:)` mapped to the right weight variant.

### `PaperSize` enum

- [ ] `.s` scale `0.90`, label `"Small"`.
- [ ] `.m` scale `1.00`, label `"Medium"`.
- [ ] `.l` scale `1.14`, label `"Large"`.
- [ ] Scaling applies only to handwriting-font elements; system-font elements (chrome, eyebrows) ignore size. Implement via a `.handwritingScale(_:)` ViewModifier.

### `CategoryPalette` (`work | personal | health | family | focus | travel`)

For each category:
- [ ] `name` — display label.
- [ ] `dot` — accent color (hex from `data.jsx`):
  - work `#0A84FF`, personal `#BF5AF2`, health `#30D158`, family `#FF375F`, focus `#FF9F0A`, travel `#64D2FF`.
- [ ] `bgLight` — `dot` at 12% alpha. `bgDark` — `dot` at 22%.
- [ ] `inkColor(in theme: PaperTheme) -> Color` — returns the per-category handwritten-pen color:
  - work → `theme.blueInk`
  - personal → `#5A2A7A` (theme-independent — verified in mock)
  - health → `theme.greenInk`
  - family → `theme.redInk`
  - focus → `#8A5A1A` (theme-independent)
  - travel → `#1A6A8A` (theme-independent)
- [ ] Document the choice to keep personal/focus/travel inks theme-independent (matches mock).

### `Typography` ramp (exact px-to-pt mapping; iOS pt == web px here)
- [ ] `pageWeekdayTitle` — handwriting 30 / weight 700 / lineHeight 1.0.
- [ ] `pageDateNumber` — handwriting 62 / weight 700 / rotation -3°.
- [ ] `pageMonthCaption` — Cochin italic 12.
- [ ] `eventTitle` — handwriting 21 / weight 600.
- [ ] `eventLocation` — Cochin italic 12.
- [ ] `eventTime` — Cochin 13, weight 600, tabular nums.
- [ ] `taskLabel` — handwriting 17 / weight 500.
- [ ] `stickyBody` — handwriting 13 / weight 600.
- [ ] `eyebrow` — system 9–10 / weight 700 / tracking 1.4–1.6 / uppercase.
- [ ] `weekChromeEyebrow` — system 10 / weight 700 / tracking 1.6 / 65% opacity.
- [ ] `dateRangePill` — handwriting 22 / weight 400 / dashed bottom border.
- [ ] `aiOverlayTitle` — handwriting 24 / weight 400.
- [ ] `aiOverlayInput` — handwriting 22 / blueInk.
- [ ] `aiSuggestion` — handwriting 18 / blueInk.
- [ ] `reviewTitle` — handwriting 28 / weight 700.
- [ ] `reviewPercent` — handwriting 48 / weight 700 / rotation -3°.
- [ ] Provide `Typography.eventTitle.font(in theme)` style accessors.

### `Spacing` constants
- [ ] `pageInset` = `EdgeInsets(top: 0, leading: 26, bottom: 0, trailing: 18)` (book-spine on the left).
- [ ] `redMarginLeading` = 32.
- [ ] `holePunchLeading` = 8, size = 12×12.
- [ ] `bookPageCornerRadius` = `RectangleCornerRadii(topLeading: 2, bottomLeading: 2, bottomTrailing: 12, topTrailing: 12)` (using `UnevenRoundedRectangle`).
- [ ] `bookOuterCornerRadius` = `RectangleCornerRadii(topLeading: 4, bottomLeading: 4, bottomTrailing: 14, topTrailing: 14)`.
- [ ] `bookTopBarTopPadding` = 54 (status bar + dynamic island clearance).
- [ ] `tabBarHeight` = 76, `tabBarBottomSafeArea` = 26.
- [ ] `pageFlipPerspective` = 1800 (used in 3D rotation).
- [ ] `pageEdgeStripeWidth` = 6.
- [ ] `sideTabWidth` = 22, `sideTabSelectedWidth` = 28, `sideTabHeight` = 56, `sideTabSelectedOffset` = -6.

### `AnimationTokens`
- [ ] `pageFlip` — duration 0.62s, curve `cubic-bezier(0.45, 0.05, 0.55, 0.95)` mapped to `Animation.timingCurve(...)`.
- [ ] `sheetSlide` — 0.32s, `cubic-bezier(0.2, 0.8, 0.2, 1)`.
- [ ] `stickyPeel` — 0.32s, `cubic-bezier(0.2, 0.8, 0.2, 1.1)` (overshoot).
- [ ] `aiThinkingShimmer` — 2.5s linear infinite background-position sweep.
- [ ] `pickerDrop` — 0.32s, `cubic-bezier(0.2, 0.8, 0.2, 1)`.
- [ ] `pickerFade` — 0.20s ease-out.

### Environment wiring
- [ ] `EnvironmentValues.paperTheme: PaperTheme` keyed by `PaperThemeEnvironmentKey`.
- [ ] `EnvironmentValues.paperFont: PaperFont` keyed by `PaperFontEnvironmentKey`.
- [ ] `EnvironmentValues.paperSize: PaperSize` keyed by `PaperSizeEnvironmentKey`.
- [ ] `View.paperTheme(_:)`, `.paperFont(_:)`, `.paperSize(_:)` convenience modifiers.
- [ ] Default theme is `.cream`, default font `.caveat`, default size `.m`.

### Color helper
- [ ] `Color(hex:)` accepting `"#RRGGBB"` and `"#RRGGBBAA"`.
- [ ] `Color(rgba:)` accepting `(r:Int, g:Int, b:Int, a:CGFloat)`.
- [ ] All theme color literals defined as `Color(hex:)` (no asset catalog colors — keeps theme switching dynamic).

## Tests (TDD)

`PaperThemeTests`
- [ ] `testCreamThemeHasExpectedHex()` — instantiates `.cream` and asserts ~20 specific color values match the spec.
- [ ] `testKraftThemeHasExpectedHex()`, `testMidnightThemeHasExpectedHex()` — same for the other two.
- [ ] `testAllThemesHaveAllProperties()` — generic test that every property is set (non-nil / non-clear) on every theme.

`CategoryPaletteTests`
- [ ] `testCategoryDotColors()` — each of 6 categories has the exact hex.
- [ ] `testInkColorForWorkInMidnightIsLightBlue()` — `work` ink in `.midnight` is `#7DB0F2`.
- [ ] `testInkColorPersonalIsThemeIndependent()` — `personal` ink is `#5A2A7A` in all three themes.

`TypographyTests`
- [ ] `testFontResolvesToCustomFont()` — for each of the 4 handwriting fonts, calling `font(at: 22, weight: .semibold)` returns a `Font` (smoke test).
- [ ] `testTypographyRampValues()` — assert sizes from the table above.

## Acceptance Criteria
- All three themes can be instantiated and every property tested.
- Environment injection compiles. A throwaway preview can read `@Environment(\.paperTheme)`.
- All tests green.
- No view code yet — the design system is the deliverable.

## Out of Scope
- Applying tokens to actual views (Phase 05+).
- Live switching from Settings (Phase 16).
- Modern (non-paper) tokens (Phase 20).

## Risks & Notes
- **160° gradient mapping.** SwiftUI's `LinearGradient` uses `startPoint`/`endPoint`. We must convert CSS-style degree-from-vertical to those points. Write a helper and test it.
- **Color blending.** SwiftUI applies sRGB by default. Cross-check a few colors against the HTML render in a side-by-side simulator screenshot.
- **Font weights.** Caveat ships 4 weights; for fonts that don't (Architects Daughter is Regular only), the `weight` parameter is ignored — document this.
