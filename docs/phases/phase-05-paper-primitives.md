# Phase 05 — Paper Primitives & Book Chrome

## Goal
Implement every reusable visual atom that the paper aesthetic depends on — leather book cover, page spine, cream page, hole punches, red margin, ruled lines, paper grain, edge stripes, page curl, binding shadow. No screen-level views yet.

## Why this is needed
Phases 06–17 compose these primitives. If we get them wrong now, every later screen drifts.

## Prerequisites
- Phase 02 (PaperTheme, Typography, Spacing, AnimationTokens).

## Files Created / Modified

```
WeeklyPlanner/DesignSystem/Primitives/BookCover.swift           # NEW — leather background
WeeklyPlanner/DesignSystem/Primitives/BookPage.swift            # NEW — composite container (spine + page surface)
WeeklyPlanner/DesignSystem/Primitives/BookSpine.swift           # NEW — inner spine layer
WeeklyPlanner/DesignSystem/Primitives/PaperSurface.swift        # NEW — cream paper with radial gradient + grain
WeeklyPlanner/DesignSystem/Primitives/RedMarginLine.swift       # NEW — vertical 1px red line at x=32
WeeklyPlanner/DesignSystem/Primitives/HolePunches.swift         # NEW — three 12×12 dots
WeeklyPlanner/DesignSystem/Primitives/RuledLines.swift          # NEW — faint horizontal lines at 28px spacing
WeeklyPlanner/DesignSystem/Primitives/EdgeStripes.swift         # NEW — page-edge stripe pattern
WeeklyPlanner/DesignSystem/Primitives/PageCurl.swift            # NEW — bottom-right 28×28 corner curl
WeeklyPlanner/DesignSystem/Primitives/BindingShadow.swift       # NEW — left binding gradient shadow
WeeklyPlanner/DesignSystem/Primitives/PaperGrain.swift          # NEW — multi-radial grain overlay
WeeklyPlanner/DesignSystem/Primitives/PageNumber.swift          # NEW — "— Month Date —" footer
WeeklyPlanner/DesignSystem/Primitives/MaskingTape.swift         # NEW — used by sticky notes
WeeklyPlanner/DesignSystem/Primitives/WavyUnderline.swift       # NEW — Text modifier
WeeklyPlanner/DesignSystem/Primitives/DashedBorder.swift        # NEW — ViewModifier
WeeklyPlanner/DesignSystem/Primitives/TornEdgeShape.swift       # NEW — zigzag Shape for event sheet top
WeeklyPlanner/DesignSystem/Primitives/InkShimmerText.swift      # NEW — "thinking..." gradient text
WeeklyPlanner/DesignSystem/Primitives/PaperToggle.swift         # NEW — toggle styled to match (used in sheets/settings)
WeeklyPlanner/DesignSystem/Primitives/PaperPillButton.swift     # NEW — small chrome pill (Today, Close, etc.)
WeeklyPlanner/DesignSystem/Previews/PrimitivesPreview.swift     # NEW — gallery preview for visual QA
WeeklyPlannerTests/Primitives/TornEdgeShapeTests.swift          # NEW
WeeklyPlannerTests/Primitives/PrimitiveSnapshotTests.swift      # NEW — uses snapshot testing
```

## Visual & Interaction Checklist

Side-by-side compare each primitive in the SwiftUI Preview against the corresponding region of `docs/mock/Weekly Planner.html` (run via Babel-standalone or screenshot).

### `BookCover`
- [ ] Full-bleed gradient. 160° from `theme.bookCoverStart` (`#2C2418` in Cream) to `theme.bookCoverEnd` (`#1A1410`).
- [ ] Use `LinearGradient(colors:..., startPoint: ..., endPoint: ...)`. Convert 160° → start `(x: 0.83, y: 0.94)`, end `(x: 0.17, y: 0.06)` (verify via helper test).
- [ ] No texture overlay; the leather effect comes from the gradient + shadows around it.

### `BookSpine`
- [ ] Solid `theme.bookSpine` color.
- [ ] Inner shadows: `inset 8px 0 14px rgba(0,0,0,0.45)` on the leading edge, `inset -4px 0 8px rgba(0,0,0,0.2)` on the trailing edge. Implement via overlay `LinearGradient`s with `.compositingGroup()`.
- [ ] Rounded corners: `RectangleCornerRadii(topLeading: 4, topTrailing: 14, bottomLeading: 4, bottomTrailing: 14)` (left is the bound edge, only slightly rounded).
- [ ] The book spine is the **parent** container; the cream page surface clips into it.

### `PaperSurface`
- [ ] Background: radial gradient — ellipse at 18% / 30%, colors `creamHi` → `cream` at 55% → `creamLo`, layered on flat `cream` fill.
- [ ] Rounded corners: `RectangleCornerRadii(topLeading: 2, topTrailing: 12, bottomLeading: 2, bottomTrailing: 12)` — slightly less rounded than the spine to nest cleanly.
- [ ] Clips child content via `.clipShape(UnevenRoundedRectangle(...))`.

### `RedMarginLine`
- [ ] 1pt-wide vertical rule at `leading: 32`. Color `theme.redLine`.
- [ ] Extends `top: 0, bottom: 0`.
- [ ] Drawn as a `Rectangle().frame(width: 1)` aligned to leading.

### `HolePunches`
- [ ] Three circles (12×12) at `leading: 8`. Y positions: `top: 60`, `centerY (50%)`, `bottom: 60`.
- [ ] Fill `theme.holePunch`.
- [ ] Inner shadow `inset 0 1 2 rgba(0,0,0,0.2)` — implement via a stacked smaller `Circle().fill(...).blur(...)` underneath.

### `RuledLines`
- [ ] Faint horizontal lines every 28pt, starting at row 0 of the content area.
- [ ] Each line is 1pt, color `theme.rule`.
- [ ] Implemented as `Canvas` to keep draw cost low.
- [ ] Subordinate to text — should sit behind all content.
- [ ] On Day Page, ruled lines start below the header; on Week Page they may be omitted (verify in mock — they're present subtly).

### `EdgeStripes`
- [ ] 6pt-wide vertical strip on the trailing edge of the book page (between page surface and outside world).
- [ ] Pattern: repeating linear gradient (180°), `theme.edgeStripeLight` (e.g., `#EFE5C9`) 0–2pt, `theme.edgeStripeDark` (e.g., `#E2D6B3`) 2–4pt.
- [ ] Rounded `0 6 6 0`.
- [ ] Inner shadow `inset -1 0 2 rgba(0,0,0,0.25)`.
- [ ] Visible only at `top: 6, bottom: 6` (slightly inset).

### `PageCurl`
- [ ] 28×28 at `bottom: 0, trailing: 0`.
- [ ] Triangle-clipped gradient `135°`: transparent 50% → `rgba(0,0,0,0.08)` 50% → `rgba(0,0,0,0.18)` 100%.
- [ ] Rounded only at bottom-trailing (`0 0 12 0`).
- [ ] Non-interactive (pointer-events none).

### `BindingShadow`
- [ ] 24pt-wide gradient strip on the leading edge of the page: `rgba(0,0,0,0.32)` → `rgba(0,0,0,0)`.
- [ ] Sits **on top** of the page surface (z-index 6) to suggest the binding curving inward.

### `PaperGrain`
- [ ] Three radial gradients (small brown dots), 35% opacity, `mix-blend-mode: multiply`.
- [ ] Positions (Day Page): `(12%, 84%) 60pt radius 0.07α`, `(88%, 22%) 80pt radius 0.05α`, `(60%, 70%) 100pt radius 0.04α`.
- [ ] Rendered in a `Canvas` for crispness.

### `PageNumber`
- [ ] Bottom-right footer: `"— {month} {date} —"` in Cochin italic, 10pt, color `theme.ink3`.
- [ ] Positioned at `bottom: 6, trailing: 14`.

### `MaskingTape` (for sticky notes)
- [ ] 32×10 rectangle, color `rgba(180,140,70,0.45)`, centered at top of the host view, offset upward by 5pt.
- [ ] Variant `wide` 36×10 used by week-sticky.

### `WavyUnderline` (ViewModifier on Text)
- [ ] Renders the text with `Path` wavy line beneath baseline.
- [ ] Color customizable (e.g., `rgba(26,58,122,0.3)` for blue ink, `rgba(26,26,42,0.25)` for ink).
- [ ] Amplitude ≈ 1pt, wavelength ≈ 6pt.
- [ ] Falls back to `.underline()` for accessibility when `accessibilityReduceMotion` or differentiated content settings demand.

### `DashedBorder` (ViewModifier)
- [ ] Configurable color, dash pattern, line width.
- [ ] Default: 0.5pt, dash `[4, 3]`. Used by event-detail category chip, Today chip, etc.

### `TornEdgeShape` (Shape)
- [ ] Custom `Shape` for the top edge of `PaperEventSheet`.
- [ ] Zigzag pattern: width 40pt, height 10pt; path `M0 10 L5 4 L10 8 L15 2 L20 7 L25 3 L30 9 L35 4 L40 10 Z`, tiled across the view width.
- [ ] Includes a 30%-overlap mask so the cream sheet appears torn rather than crudely jagged.
- [ ] Output is used both as `.clipShape(...)` and as a top-edge accent fill (overlay).

### `InkShimmerText`
- [ ] Renders a `Text` with a linear-gradient fill that animates `background-position` `-200% → 200%` over 2.5s linear infinite.
- [ ] Gradient colors: `[blueInk, redInk, greenInk, blueInk]`.
- [ ] Implementation: `Text(...).foregroundStyle(animatedGradient)` using a `TimelineView` to animate.
- [ ] Respects `accessibilityReduceMotion` (static gradient when reduced).

### `PaperToggle`
- [ ] 38×22 (event detail rows) or 44×26 (settings rows). Provide both sizes via `style: .compact | .regular`.
- [ ] On color: `theme.greenInk` (`#30D158` in modern). Off color: `rgba(120,120,128,0.32)`.
- [ ] Knob: white circle, 18 or 22pt, with a soft shadow `0 1 3 rgba(0,0,0,0.15)`.
- [ ] Slide animation 0.2s on `cubic-bezier(0.3, 0.8, 0.4, 1)`.

### `PaperPillButton`
- [ ] Rounded 999 corners. 5×11pt padding (compact) or 6×14pt (default).
- [ ] Primary variant: `theme.blueInk` background, `theme.cream` text.
- [ ] Secondary: transparent bg, `theme.ink3` border, `theme.ink` text.
- [ ] Uppercase, 11pt system bold, letter-spacing 0.4.

## Logic & Data Checklist

- [ ] Each primitive reads from `@Environment(\.paperTheme)`. None hardcode colors.
- [ ] `BookPage` is the parent composite: `BookCover` is rendered by the host screen (full-bleed); `BookPage` renders the spine + edge stripes + paper surface + binding shadow. Content is injected via `@ViewBuilder content`.
- [ ] Order of layers inside `BookPage` (back to front):
  1. `BookSpine` (provides rounded corner clip)
  2. `EdgeStripes` (right edge, z=1)
  3. `PaperSurface` (clipped inside spine)
     - inside the surface: `PaperGrain`, `RuledLines`, `RedMarginLine`, `HolePunches`, then content.
  4. `BindingShadow` (z=6, on top of content's left edge)
  5. `PageCurl` (z=7, on top of content's bottom-right)
- [ ] All primitives accept `alignmentGuide` modifiers so screen-level layouts can position them precisely.
- [ ] All animations honor `Animation.reduced` when accessibility setting is on.

## Tests (TDD)

`TornEdgeShapeTests`
- [ ] `testPathContainsExpectedPoints()` — sample the path at known X positions and assert Y matches the zigzag.

`PrimitiveSnapshotTests` (using `swift-snapshot-testing` SPM dep, added in Phase 01 if approved; otherwise hand-rolled image diff)
- [ ] Snapshot per primitive at 1× and 3× for each of three themes.
- [ ] Diffs against `__Snapshots__/<theme>/<primitive>.png` checked into the repo.
- [ ] Tolerance 0.5% pixel diff.

> **Decision:** add `pointfreeco/swift-snapshot-testing` to SPM. If skipped, replace with manual visual QA checklist in the phase doc.

## Acceptance Criteria
- Every primitive renders in the gallery preview matching the mock at 1pt accuracy in three themes.
- Snapshot tests pass for cream theme; kraft + midnight snapshots authored from approved cream baseline.
- Primitives drop into a placeholder day-page composition without any layout debt.

## Out of Scope
- The day page composition (Phase 06).
- Event-level content rendered on top of the paper (Phase 06, 07).
- Page-flip motion (Phase 08).

## Risks & Notes
- **Repeating linear gradient** isn't first-class in SwiftUI. Implement `EdgeStripes` with `Canvas { ctx in ... }` drawing 2-pt rectangles in a loop, or by stacking many slim `Rectangle()`s.
- **Wavy underline** must not break text wrapping. Implement via a `.overlay(alignment: .bottom) { ... }` of a `Canvas` synced to the text's measured width via `GeometryReader`.
- **PaperGrain** at 35% opacity with multiply blend mode is critical to avoid the page looking flat. Test on OLED + LCD devices.
- **Hole punches' inner shadow** is easy to over-do; keep subtle.
