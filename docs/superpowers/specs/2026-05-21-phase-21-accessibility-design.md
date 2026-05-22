# Phase 21 — Accessibility, Dynamic Type, Localization, RTL

**Status:** Design approved · ready for implementation plan
**Branch:** `milestone-i-polish` (off `main` at `7b08d4b`; already +1 commit from the Phase 20 archive doc)
**Phases bundled:** 21 only (Milestone I = Phase 21 after Phase 20 was archived on 2026-05-21)
**Source phase doc:** `docs/phases/phase-21-accessibility.md`

---

## 1. Scope & shape

### What ships

One branch, one phase. Phase 21 covers five concerns shipped as one coherent merge:

1. **VoiceOver audit + gap-fill** across the Paper view tree (Day, Week, Review, Settings, AI overlay, Event sheet) — Paper code has accessibility labels in 28 files today; review for correctness/completeness + fill gaps (notably Review which has zero coverage).
2. **Centralized accessibility modifiers** for composite/DRY surfaces (event rows, task rows, side tabs, today pill, AI button, week-picker rows) — about 6–8 helpers in `AccessibilityModifiers.swift`. One-offs stay inline.
3. **Custom rotors** — `accessibilityRotor("Events")` on `DayPageView`, `accessibilityRotor("Days")` on `PaperWeekView`.
4. **Dynamic Type two-track** — system text auto-scales; handwriting fonts wrap via `DynamicTypeSupport.handwriting(...)` with `.xxxLarge` clamp. Layout adapter widens time gutter / side tabs at AX2+ and hides tab-bar labels at AX4+.
5. **Reduce Motion alternative animations** — centralized `Animation.*(reduced:)` factories on existing `AnimationTokens` for page flip, sheet slide, sticky peel, AI overlay. Ink shimmer skips its `TimelineView`. Tab bookmark cross-fade stays.
6. **WCAG AA contrast** — `ink3` raised 34% → 50% alpha (cream contrast ≈4.1:1); decorative-only uses split off to new `inkDecorative = 30%` with `.accessibilityHidden(true)`. Bold Text font weight swap via `PaperFont.weightFor(legibility:)`.
7. **RTL layout** — standard SwiftUI mirroring handles HStack/VStack axes; directional images get `.flipsForRightToLeftLayoutDirection(true)`; page-flip gesture inverts deltaX explicitly; DayPageHeader rotation flips sign.
8. **`Localizable.xcstrings` scaffolding** — create the catalog, migrate all user-facing `Text(...)` literals (~69 in `Features/` plus DesignSystem strings), seed English (US), no other translations ship. `InfoPlist.xcstrings` for usage descriptions. `IntelligenceService` LLM prompts stay English-only (not user-facing UI).
9. **`XCUIAccessibilityAudit`-based regression gates** — one per major screen in a new `AccessibilityAuditUITests`. Baseline 0 issues; documented exceptions inline.
10. **`AccessibilityIDs.swift`** — stable identifiers for UI tests (e.g., `daypage.event.row.<uuid>`).

Final merge commit:
`Merge branch 'milestone-i-polish' (Phase 20 archived; Phase 21 — Accessibility, Dynamic Type, Localization, RTL)`

### What does NOT ship

Carried forward as-stated in the source phase doc and confirmed during brainstorming:

- **Translations for non-English locales** — scaffolding only. Translator handoff (xcloc) is post-v1.0.
- **VoiceOver custom gesture actions** beyond what `.accessibilityAction` covers.
- **Switch Control specific tuning** — falls out of correct traits + labels.
- **Smart Invert support** — the paper aesthetic is inherent; Midnight theme is the "dark" alternative.
- **`swift-snapshot-testing` SPM dep** — consistent with Phases 16–19. `XCUIAccessibilityAudit` + structural-invariant tests + on-device verification cover regressions.
- **Localization of `IntelligenceService` prompts** — they're LLM inputs, not user-facing strings.
- **VoiceOver pronunciation overrides** unless on-device verification reveals a specific handwriting font reads wrong; then add `accessibilityValue` overrides reactively.

### Milestone-level acceptance

1. VoiceOver users can navigate Day → Week → Review → Settings → AI overlay → Event sheet and complete every primary task (open event, toggle to-do, ask AI, change theme, connect Gmail) end-to-end without missing labels.
2. `XCUIAccessibilityAudit` passes **0 issues** on all 6 major screens at default Dynamic Type, light theme. Documented exceptions (e.g., decorative shadows) are inline-commented.
3. App renders correctly at **AX5 Dynamic Type** — no clipping, no overlapping. Handwriting fonts clamp at xxxLarge.
4. `accessibilityReduceMotion = true` disables flips, sheet slides, sticky peel, ink shimmer per the table in §4.
5. **RTL layout mirrors correctly** when device locale is Arabic/Hebrew. Page-flip gesture inverts.
6. All user-facing `Text("...")` literals live in `Localizable.xcstrings`. `LocalizationTests` regex scanner catches stragglers.
7. **Bold Text** swaps handwriting weights per the table in §4 (Caveat Regular→SemiBold, Kalam Light→Regular).
8. Full unit + UI test suite green at every commit. Target: 276 → ~301 unit + 8 UI = ~309 total.

### Test budget

~25 unit tests added (modifier label formatting × 6, layout adapter × 4, contrast × 2, reduce motion × 3, localization × 3, RTL structural × 3, accessibility integration × 4) + 8 XCUITests (audit × 6, VoiceOver smoke + rotor × 2).

---

## 2. Module layout & accessibility approach

### 2.1 New module

```
WeeklyPlanner/Accessibility/
├── AccessibilityIDs.swift              # stable UI-test identifiers
├── DynamicTypeSupport.swift            # handwriting font wrappers + layout adapter
├── ReduceMotionAnimations.swift        # extension on AnimationTokens; reduced/full factories
└── AccessibilityModifiers.swift        # .accessibleEvent(_:), .accessibleTask(_:), etc.

WeeklyPlanner/Resources/
├── Localizable.xcstrings               # NEW (English seeded)
└── InfoPlist.xcstrings                 # NEW (usage descriptions)
```

### 2.2 VoiceOver via centralized modifiers + inline annotations

**Centralized** (in `AccessibilityModifiers.swift`):

- `.accessibleEvent(_ event: Event)` → label `"{title}, {category.displayName}, {weekday} {timeRange}, {location-or-'no location'}, source {Gmail | added by you}"`, hint `"Double tap to open details."`, trait `.button`.
- `.accessibleTask(_ task: TaskItem)` → label `"{title}, {completed | not completed}"`, custom action toggle, trait `.button`.
- `.accessibleSideTab(weekday: WeekDay, dayN: Int)` → label `"{Weekday}, day {N} of 7"`, hint `"Double tap to flip to this day."`, trait `.button`.
- `.accessibleTodayPill()` → label `"Return to today"`, trait `.button`.
- `.accessibleAIButton()` → label `"Apple Intelligence search"`, hint `"Double tap to ask about your week."`, trait `.button`.
- `.accessibleWeekRow(meta: WeekMeta)` → label `"Week of {range}, week {n}"`, hint `"Double tap to jump to this week."`, trait `.button`.

**Inline** for one-offs already covered by the 28 existing files — keep the existing `.accessibilityLabel("Open Apple Intelligence search")` where it lives. Don't refactor working code for consolidation. Audit each existing site for: meaningful label, hint when action non-obvious, correct trait, composite-row grouping via `.accessibilityElement(children: .combine)`.

### 2.3 Audit pass scope

| Surface | Files | Status today | Phase 21 action |
|---|---|---|---|
| `DayPage/` | 11 files | covered | Audit grouping (combine vs separate), trait correctness, hint quality. Add Events rotor. |
| `WeekPage/` | 1 file w/ labels | partial | Fill gaps, add Days rotor. |
| `Review/` | 0 of 6 files | **zero coverage** | Annotate from scratch — header, AI summary, time bars, insights, streak block. |
| `EventDetail/` | 6 files | covered | Audit composite-row grouping (location row, reminder row, etc.). |
| `AISearch/` | 2 files | covered | Confirm `.searchField` trait on input; citation chip labels. |
| `Settings/` | mixed | partial | Fill logo gaps (Apple/Gmail/Google), add `.isSelected` trait to theme/font/style/size cards. |
| `Navigation/` | tab bar, side tab, page-flip | partial | Tab trait, "{tab}" labels, gesture-handle `.accessibilityHidden(true)`. |
| `WeekPicker/` | 2 files | covered | Audit week-row labels with full date format. |
| `DesignSystem/Primitives/` | hole punches, page-curl, red margin, ruled lines, dashed seams, ink shimmer | not annotated | `.accessibilityHidden(true)` — all decorative. |

### 2.4 Custom rotors

- `accessibilityRotor("Events") { ForEach(visibleEvents) { event in AccessibilityRotorEntry(event.title, id: event.id) } }` on `DayPageView`.
- `accessibilityRotor("Days") { ForEach(weekDays) { day in AccessibilityRotorEntry(day.weekdayFull, id: day.id) } }` on `PaperWeekView`.

### 2.5 `AccessibilityIDs.swift`

Stable identifiers for UI tests:

```swift
enum AccessibilityIDs {
    static func daypageEventRow(_ id: UUID) -> String { "daypage.event.row.\(id)" }
    static func daypageTodoRow(_ id: UUID) -> String { "daypage.todo.row.\(id)" }
    static func weekpickerWeekRow(_ offset: Int) -> String { "weekpicker.weekrow.\(offset)" }
    static func settingsThemeCard(_ key: String) -> String { "settings.theme.card.\(key)" }
    static func settingsFontCard(_ key: String) -> String { "settings.font.card.\(key)" }
    static let aiSearchInput = "aisearch.input"
    static let aiButton = "daypage.ai.button"
    static let todayPill = "daypage.today.pill"
    // ...
}
```

---

## 3. Dynamic Type, Reduce Motion, contrast

### 3.1 Dynamic Type — two-track

**System fonts** (Cochin captions, SF Pro where used) → `Font.body`/`.subheadline`/etc. — automatic scaling, no per-call work.

**Handwriting fonts** (Caveat, Architects Daughter, Kalam, Indie Flower) → wrap via:

```swift
extension DynamicTypeSupport {
    static func handwriting(_ font: PaperFont, size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        Font.custom(font.familyName(weight: .regular), size: size, relativeTo: style)
    }
}
```

Apply `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` on the host views (Day page, Week page, AI sticky notes, To-Do rows, event titles) to clamp scaling.

### 3.2 Layout adapter (`DynamicTypeLayout`)

```swift
enum DynamicTypeLayout {
    static func timeGutterWidth(at: DynamicTypeSize) -> CGFloat       // 48 below AX2; 64 at AX2+
    static func sideTabWidth(at: DynamicTypeSize) -> CGFloat          // 22 below AX2; 32 at AX2+
    static func tabBarLabelStyle(at: DynamicTypeSize) -> TabBarLabelStyle  // .full | .truncate (AX3) | .iconOnly (AX4+)
}

enum TabBarLabelStyle { case full, truncate, iconOnly }
```

`PaperTabBar`, `SideTab`, and `DayPageView` (any time-gutter) read these via `@Environment(\.dynamicTypeSize)`.

### 3.3 Reduce Motion — extend `AnimationTokens`

```swift
extension AnimationTokens {
    static func pageFlip(reduced: Bool) -> Animation {
        reduced ? .easeInOut(duration: 0.15) : Self.pageFlip
    }
    static func sheetSlide(reduced: Bool) -> Animation {
        reduced ? .easeOut(duration: 0.15) : Self.sheetSlide
    }
    static func stickyPeel(reduced: Bool) -> Animation {
        reduced ? .linear(duration: 0) : Self.stickyPeel
    }
    static func aiOverlaySlide(reduced: Bool) -> Animation {
        reduced ? .easeOut(duration: 0.2) : Self.aiOverlaySlide
    }
}
```

Each animated view reads `@Environment(\.accessibilityReduceMotion)` once and passes the `Bool` to the factory. **Ink shimmer**: `InkShimmerText` short-circuits its `TimelineView` when reduced → static gradient. **Tab bookmark cross-fade** stays animated unconditionally (brief, conveys state).

| Surface | Full animation | Reduced |
|---|---|---|
| Day page flip | 3D `rotation3DEffect` ~0.5s | 0.15s opacity crossfade |
| Modal sheet (Event detail, Week picker, AI overlay) | Standard slide | 0.15-0.2s fade |
| Sticky note peel/unpeel | ~0.3s peel curve | Instant |
| Ink shimmer | `TimelineView` rotating gradient | Static gradient |
| Tab bar bookmark | 0.18s cross-fade | 0.18s cross-fade *(unchanged)* |

### 3.4 WCAG AA contrast — one-time PaperTheme audit

- `ink3` raised from **34% → 50% alpha** (target ≈4.1:1 on cream). New token **`inkDecorative = 30% alpha`** for page-number footer, hole-punch shadows, dashed seams. All `inkDecorative` consumers also get `.accessibilityHidden(true)`.
- Midnight: `blueInk #7DB0F2` on `#1E1F2D` ≈ 6.8:1 ✓ (no change).
- Kraft: `ink #3A2418` on `#E6D2A8` ≈ 7.4:1 ✓ (no change).
- **Bold Text**: extend `PaperFont` with `func weightFor(legibility: LegibilityWeight) -> Font.Weight` — Caveat Regular→SemiBold, Kalam Light→Regular, Indie Flower stays (single weight), Architects Daughter stays (single weight). Views consult `@Environment(\.legibilityWeight)` and pass through.

`ContrastTests` asserts the constants:

```swift
func testInk3Alpha_meetsAccessibleBodyContrast() {
    XCTAssertEqual(PaperTheme.cream.ink3.opacity, 0.5, accuracy: 0.001)
}
func testInkDecorative_isHiddenFromAccessibility() {
    // Render a Primitive that uses inkDecorative → assert .accessibilityHidden(true) modifier applied.
}
```

---

## 4. RTL & localization

### 4.1 RTL

- **Standard SwiftUI mirroring** handles HStack/VStack axes automatically.
- `.flipsForRightToLeftLayoutDirection(true)` on directional Image assets (page-flip chevrons, page curl, any asymmetric SVG).
- **Page-flip gesture deltaX inversion is explicit**: gesture handler reads `@Environment(\.layoutDirection)` and applies `deltaX = layoutDirection == .rightToLeft ? -deltaX : deltaX` before computing flip progress.
- **DayPageHeader giant date number rotation**: `+3°` in RTL, `-3°` in LTR (sign flips).
- Side tabs anchor opposite to layout direction. Red margin moves to right. Hole punches mirror.
- Strings flow RTL natively when locale is Arabic/Hebrew.

### 4.2 `Localizable.xcstrings` migration

- Create `WeeklyPlanner/Resources/Localizable.xcstrings` (Xcode String Catalog format — first added empty, populated on next build via Xcode's catalog scanner picking up `Text(...)` literals).
- Create `WeeklyPlanner/Resources/InfoPlist.xcstrings` for `NSCalendarsUsageDescription`, `NSContactsUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSUserNotificationsUsageDescription`, etc.
- **Convert `Text("...")` literals**: SwiftUI accepts string literals as `LocalizedStringKey` by default, so most call sites need NO changes — they just need to be picked up by the catalog scanner. Manual pass for:
  - **String interpolation**: `Text("\(count) events")` → use `Text("^[\(count) event](inflect: true)")` (Apple's automatic-grammar markup) OR explicit `String.LocalizationValue("%lld events")` with a stringsdict-style plural variation in the catalog.
  - **`Text(verbatim:)`** sites stay non-localized (user names, numeric IDs, etc.) — `LocalizationTests` allowlists these.
  - **Concatenations**: any `Text("X") + Text(" - ") + Text("Y")` should be rewritten as a single LocalizedStringKey with positional substitutions.
- Approx surface: ~69 `Text(...)` literals in `WeeklyPlanner/Features/**` plus a handful in DesignSystem (e.g., AboutFooter copy). Xcode's catalog scanner extracts them automatically — manual work is the interpolation/plural cases.
- `Date.FormatStyle` + `Calendar.current` already used throughout — locale-driven date/number formatting works automatically.
- **English (US) seeded.** Other translations deferred post-v1.0.
- **`IntelligenceService` prompts stay English-only** — NOT touched by this migration.

### 4.3 `LocalizationTests`

Three tests scan `WeeklyPlanner/**.swift` for:

1. `Text("..."` literals NOT matched by `Text(verbatim:)` or a documented allowlist (e.g., `#Preview` blocks) → fail on unwrapped hardcoded English.
2. Plurals format correctly: render `Text("^[\(2) events](inflect: true)")` and assert it produces "2 events" / "1 event" / "0 events" per English rules.
3. Date format honors `Locale.current`: render a `Date.FormatStyle.dateTime` with a non-en locale, assert output uses that locale's conventions.

---

## 5. Tests & acceptance gates

### 5.1 Test files

```
WeeklyPlannerTests/Accessibility/
├── AccessibilityModifierTests.swift        # ~6 tests
├── DynamicTypeLayoutTests.swift            # ~4 tests
├── ContrastTests.swift                     # ~2 tests
├── ReduceMotionTests.swift                 # ~3 tests
├── LocalizationTests.swift                 # ~3 tests
└── RTLLayoutTests.swift                    # ~3 tests

WeeklyPlannerUITests/
├── AccessibilityAuditUITests.swift         # 6 tests (Day, Week, Review, Settings, AISearch, EventSheet)
└── AccessibilityVoiceOverUITests.swift     # 2 tests (smoke flow + Events rotor)
```

### 5.2 Test types

- **Structural-invariant unit tests** (XCTest) — same pattern as Phases 16–19 (per memory `[[phase-20-reverted]]` lessons).
- **`XCUIAccessibilityAudit`** per major screen via `XCUIApplication.performAccessibilityAudit(for: .all)`.
- **Two XCUITest flows** for VoiceOver + rotor smoke that can't be exercised at unit level.

### 5.3 Acceptance gates (the 8 items)

(Reproduced from §1's "Milestone-level acceptance" for one-page reference.)

1. VoiceOver navigation through every primary task end-to-end on Paper.
2. `XCUIAccessibilityAudit` 0 issues on all 6 major screens.
3. AX5 Dynamic Type render check — no clipping/overlap, handwriting clamps at xxxLarge.
4. Reduce Motion table in §3.3 honored.
5. RTL layout mirrors at Arabic locale.
6. All user-facing strings in `Localizable.xcstrings`.
7. Bold Text font weight swaps per §3.4.
8. Test suite count: 276 → ~309 (~25 unit + 8 UI), all green at every commit.

### 5.4 On-device verification gate (user, post-merge)

- VoiceOver pass through Paper screens on the iPhone 17 Pro simulator (or device).
- AX5 render check on Day page across all 4 handwriting fonts.
- iOS Settings → Accessibility → Reduce Motion → confirm flips become crossfades.
- iOS Settings → General → Language → Arabic → confirm side tabs flip right, page-flip gesture inverts.
- iOS Settings → Accessibility → Bold Text → confirm Caveat renders as SemiBold.

---

## 6. Risks & known unknowns

1. **VoiceOver pronunciation of handwriting-font text.** Some custom fonts use private-use-area unicode mappings that confuse VoiceOver. *Mitigation:* test all 4 handwriting fonts during on-device verification. Add `accessibilityValue` overrides with plaintext only if a font reads wrong.

2. **AX5 layout regressions in Paper Day page.** Time gutter widens, side tabs widen, event blocks shrink — may cause text clipping in event titles. *Mitigation:* `.lineLimit(2)` + tap to open full event sheet. Test all 4 handwriting fonts at AX5 on device.

3. **String catalog one-shot migration risk.** Xcode's catalog scanner can miss interpolated strings and `Text(verbatim:)` mis-uses. *Mitigation:* `LocalizationTests` regex catches stragglers; manual pass on `Features/AISearch/` and `Features/Settings/` (highest copy density).

4. **RTL page-flip gesture direction.** Standard mirroring handles layout axes but not gesture deltaX inversion. *Mitigation:* explicit `if layoutDirection == .rightToLeft { deltaX = -deltaX }` in the gesture handler. Covered by `RTLLayoutTests`.

5. **`XCUIAccessibilityAudit` exceptions accumulate.** Some issues are unavoidable (decorative shadows, tab-bar bookmark trait quirks). *Mitigation:* document each exception inline with a one-line comment. CI fails on new unexpected issues, not on documented ones.

6. **PaperTheme contrast change might regress visual identity.** Raising `ink3` from 34% → 50% makes captions more legible but also more present visually. *Mitigation:* manual mock diff against `docs/mock/` after the change; if it's noticeably wrong, fall back to 40% and re-test contrast.

7. **Bold Text font availability.** Caveat, Kalam, Architects Daughter, Indie Flower — verify each font family includes the weights we want to swap to. *Mitigation:* if a target weight is missing, fall back to the next-heavier available weight; document inline.

8. **iOS 26 String Catalog quirks.** `Localizable.xcstrings` is a relatively new format. Xcode 26.5 may not auto-extract some interpolation patterns. *Mitigation:* `LocalizationTests` regex scanner; manual catalog audit before claiming acceptance.

9. **Existing Phase 17–19 logging/auth/inbox surfaces may have hardcoded English in alerts/banners.** *Mitigation:* the LocalizationTests scanner runs across the whole `WeeklyPlanner/` tree, not just `Features/`.

---

## 7. Execution plan

After this spec is approved:

1. **`superpowers:writing-plans`** produces a task-level implementation plan with:
   - Module scaffolding first (AccessibilityIDs, DynamicTypeSupport, ReduceMotionAnimations, AccessibilityModifiers).
   - Per-surface audit passes (one task per Day / Week / Review / Settings / EventSheet / AISearch).
   - Contrast token bump + Bold Text swap.
   - Layout adapter wiring (time gutter, side tabs, tab bar).
   - Reduce Motion factory wiring at each animated call site.
   - RTL fixes (page-flip deltaX, header rotation sign).
   - `Localizable.xcstrings` + `InfoPlist.xcstrings` creation + `Text(...)` migration.
   - XCAccessibilityAudit per screen.
   - VoiceOver smoke flow + Events rotor UI tests.
   - On-device verification gate + retro entry.
2. **`superpowers:subagent-driven-development`** executes the plan, one task per dispatch, with the lessons from `[[phase-20-reverted]]` applied (XCTest patterns inline, explicit "END with STATUS report" termination contract, file paths under `WeeklyPlannerTests/Features/...` or `WeeklyPlannerTests/Accessibility/`).
3. **On-device verification** before merge to `main`.
4. **Retro entry** appended to `docs/phases/README.md` for Phase 21.
5. **Final merge commit** to `main` with the message above.

---

**End of design.**
