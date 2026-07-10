# Phase 44 — Typography & Paper Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two new text-size tiers (XL 1.32×, XXL 1.50×) plus a sweep making fixed-size headers scale; a bigger scaled day-date caption; a brand-new paper-template system (Ruled/Blank/Dot grid/Grid) unified behind one `PaperBackground` component; 4 new fonts; Settings loses the Theme picker and gains Font + Paper sections (suggestions #58, #59, #62, #77, #78, #79).

**Architecture:** `PaperSize` gains `.xl`/`.xxl`; `SizeSegmented` becomes data-driven over `allCases`. Paper templates mirror the existing personalization pattern exactly: `PaperTemplate` enum ↔ `UserSettings.templateKey` string ↔ `\.paperTemplate` environment key, resolved and injected in `AppShell` beside theme/font/size. The 6 copy-pasted `ZStack { PaperGrain(); RuledLines(); RedMarginLine(); HolePunches() }` sites collapse into `PaperBackground(showsHolePunches:)`, which branches on the template. Theme stays as an internal type locked to `.cream`; only the picker UI is deleted, with a one-time kraft/midnight → cream migration.

**Tech Stack:** SwiftUI (Canvas), SwiftData, XCTest, XcodeGen. New fonts: OFL-licensed TTFs from Google Fonts.

## Global Constraints

- iOS 26.0+, Swift 6 strict concurrency, SwiftUI only.
- `xcodegen generate` after adding/deleting files (fonts auto-glob into the target; `Info.plist` still needs manual `UIAppFonts` entries). Canonical test command:

```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=<available iPhone, iOS 26.5>' \
  -only-testing:<filter> \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

- Copy is exact: Settings section titles **"Font"** and **"Paper"**; template display names **"Ruled" / "Blank" / "Dot grid" / "Grid"**; size display names **"Small" / "Medium" / "Large" / "XL" / "XXL"**.
- Scales are exact: `.s 0.90, .m 1.00, .l 1.14, .xl 1.32, .xxl 1.50`.
- The **Connections** section and the week-start row are untouched (36b owns week-start).
- If Phase 45 has landed, `PaperReviewView` no longer exists — the ruling-site sweep covers 5 sites, not 6. Re-grep, don't assume.
- Lint: changed files only, no new violations.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `WeeklyPlanner/DesignSystem/PaperSize.swift` | MODIFY | `.xl`/`.xxl` cases + scales |
| `WeeklyPlanner/Features/Settings/SizeSegmented.swift` | MODIFY | data-driven 5-segment control |
| `WeeklyPlanner/Features/DayPage/DayPageHeader.swift` | MODIFY | scaled 16pt caption |
| `WeeklyPlanner/Features/WeekPage/WeekPageHeader.swift` (+ sweep finds) | MODIFY | `* size.scale` |
| `WeeklyPlanner/DesignSystem/PaperTemplate.swift` | NEW | template enum |
| `WeeklyPlanner/DesignSystem/Primitives/DotGrid.swift` | NEW | dot-grid Canvas |
| `WeeklyPlanner/DesignSystem/Primitives/GridLines.swift` | NEW | square-grid Canvas |
| `WeeklyPlanner/DesignSystem/Primitives/PaperBackground.swift` | NEW | unified paper stack |
| 6 (or 5) ruling sites | MODIFY | call `PaperBackground` |
| `WeeklyPlanner/Models/UserSettings.swift` | MODIFY | `templateKey` + accessor |
| `WeeklyPlanner/DesignSystem/Environment+Paper.swift` | MODIFY | `paperTemplate` entry + modifier |
| `WeeklyPlanner/Navigation/AppShell.swift` | MODIFY | resolve/inject template; cream migration |
| `WeeklyPlanner/Resources/Fonts/*.ttf` (4 new) + `Supporting/Info.plist` | ADD | font bundling |
| `WeeklyPlanner/DesignSystem/PaperFont.swift` | MODIFY | 4 new cases |
| `licenses/` + `README.md` | ADD/MODIFY | OFL texts + note |
| `WeeklyPlanner/Features/Settings/PaperSettingsView.swift` | MODIFY | drop Theme; Font/Paper sections |
| `WeeklyPlanner/Features/Settings/PaperCardsGrid.swift` | NEW | template picker cards |
| `WeeklyPlanner/Features/Settings/ThemeCardsGrid.swift`, `ThemeCard.swift` | DELETE | theme picker |
| `WeeklyPlanner/Features/Settings/SettingsViewModel.swift` | MODIFY | `setTemplate`; drop `setTheme` |
| tests | NEW/MODIFY | per task |

---

### Task 1: `PaperSize` XL/XXL + data-driven segmented control

**Files:**
- Modify: `WeeklyPlanner/DesignSystem/PaperSize.swift` (~lines 7–28)
- Modify: `WeeklyPlanner/Features/Settings/SizeSegmented.swift`
- Test: `WeeklyPlannerTests/DesignSystem/PaperFontTests.swift` (`PaperSizeTests` class), `WeeklyPlannerTests/Features/Settings/PaperSettingsViewTests.swift`

- [ ] **Step 1: Update the failing tests.** In `PaperSizeTests`, replace `testScaleFactorsMatchSpec` and add coverage:

```swift
    func testScaleFactorsMatchSpec() {
        XCTAssertEqual(PaperSize.s.scale, 0.90, accuracy: 0.001)
        XCTAssertEqual(PaperSize.m.scale, 1.00, accuracy: 0.001)
        XCTAssertEqual(PaperSize.l.scale, 1.14, accuracy: 0.001)
        XCTAssertEqual(PaperSize.xl.scale, 1.32, accuracy: 0.001)
        XCTAssertEqual(PaperSize.xxl.scale, 1.50, accuracy: 0.001)
    }

    func testDisplayNames() {
        XCTAssertEqual(PaperSize.allCases.map(\.displayName),
                       ["Small", "Medium", "Large", "XL", "XXL"])
    }
```

In `PaperSettingsViewTests`, update `testPaperSizeCountIsThreeSoSizeSegmentedFits` → count == 5 (rename accordingly).

- [ ] **Step 2: Run to verify failure** — `-only-testing:WeeklyPlannerTests/PaperSizeTests`. Expected: FAIL.

- [ ] **Step 3: Implement.** `PaperSize.swift`:

```swift
enum PaperSize: String, CaseIterable, Sendable {
    case s
    case m
    case l
    case xl
    case xxl

    /// Multiplier applied to every `font.font(at: n * size.scale, …)` call.
    var scale: CGFloat {
        switch self {
        case .s: 0.90
        case .m: 1.00
        case .l: 1.14
        case .xl: 1.32
        case .xxl: 1.50
        }
    }

    var displayName: String {
        switch self {
        case .s: "Small"
        case .m: "Medium"
        case .l: "Large"
        case .xl: "XL"
        case .xxl: "XXL"
        }
    }
}
```

(Preserve any other existing members of the enum verbatim.) `SizeSegmented.swift`: replace the hardcoded 3-segment layout and `displaySize` map with `ForEach(PaperSize.allCases, id: \.self)`; per-segment preview glyph size = `13 + 3 × index` (derive from `PaperSize.allCases.firstIndex`); keep `AccessibilityIDs.settingsSizeSegment(_:)` per segment. Five segments may need a slightly tighter horizontal padding — match the existing control's chrome.

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/PaperSizeTests -only-testing:WeeklyPlannerTests/PaperSettingsViewTests -only-testing:WeeklyPlannerTests/SettingsViewModelTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/DesignSystem/PaperSize.swift WeeklyPlanner/Features/Settings/SizeSegmented.swift WeeklyPlannerTests/
git commit -m "feat(type): XL + XXL text sizes (Phase 44 #58 #79)"
```

---

### Task 2: Scale sweep — day-date caption + fixed headers

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageHeader.swift` (caption, ~lines 38–40)
- Modify: `WeeklyPlanner/Features/WeekPage/WeekPageHeader.swift` (~line 24) + whatever the sweep finds
- Test: extend `WeeklyPlannerTests/DesignSystem/TypographyTests.swift`

- [ ] **Step 1: Sweep for unscaled sizes.** `grep -rn "font(at: [0-9]" WeeklyPlanner/Features/ | grep -v "size.scale"` and `grep -rn "\.custom(\"Cochin" WeeklyPlanner/`. Inventory the hits (known: `DayPageHeader` caption 12pt Cochin fixed; `WeekPageHeader` 30pt fixed; `WeekDayRow` day number 32pt fixed and weekday-short 9pt system). Decide per hit: page-level text scales; micro-chrome (9pt eyebrows) may stay fixed — record each decision in the commit message.

- [ ] **Step 2: Day-date caption** (`DayPageHeader.swift` ~:38–40) — the item #62 deliverable:

```swift
            Text(Self.caption(for: weekDay))
                .font(.custom("Cochin-Italic", size: 16 * size.scale))
                .foregroundStyle(theme.ink2)
```

(was fixed `size: 12`; the header already has `@Environment(\.paperSize) size` — if not, add it.)

- [ ] **Step 3: Week header + sweep hits** — e.g. `WeekPageHeader.swift:24`: `font.font(at: 30 * size.scale, weight: .bold)`; `WeekDayRow` day number: `font.font(at: 32 * size.scale, weight: .bold)`.

- [ ] **Step 4: Pin it in tests** (`TypographyTests` — follow the file's existing ramp-pin style; if the caption size lives inline rather than in `Typography`, add a constant `DayPageHeader.captionPointSize: CGFloat = 16` and pin that):

```swift
    func testDayDateCaptionIsSixteenPoints() {
        XCTAssertEqual(DayPageHeader.captionPointSize, 16, "Feedback #62: date under weekday must be ≥16pt")
    }
```

- [ ] **Step 5: XXL layout pass.** Build & run (signed sim), set XXL, eyeball Day/Week/event sheet for clipping; fix with `lineLimit`/`minimumScaleFactor`/padding as needed — sparse pages keep their `minHeight` floors (Phase 34 lesson).

- [ ] **Step 6: Run** — `-only-testing:WeeklyPlannerTests/TypographyTests -only-testing:WeeklyPlannerTests/WeekDayRowTests`, then **Commit**

```bash
git add WeeklyPlanner/ WeeklyPlannerTests/
git commit -m "feat(type): scale day-date caption + fixed headers with text size (Phase 44 #62 #58)"
```

---

### Task 3: `PaperTemplate` + `PaperBackground` refactor (no new looks yet)

**Files:**
- Create: `WeeklyPlanner/DesignSystem/PaperTemplate.swift`, `WeeklyPlanner/DesignSystem/Primitives/PaperBackground.swift`
- Modify: `WeeklyPlanner/Models/UserSettings.swift`, `WeeklyPlanner/DesignSystem/Environment+Paper.swift`, `WeeklyPlanner/Navigation/AppShell.swift`
- Modify: the ruling sites — re-grep `grep -rln "RuledLines()" WeeklyPlanner/Features/` (known: `DayPageView.swift:146-149`, `WeekPageView.swift:47-50`, `PaperSettingsView.swift:25-28`, `PaperNotesView.swift:16-19`, `PaperReviewView.swift:28-31` *(if still present)*, `AISearchPaperSheet.swift:36-39`)
- Test: `WeeklyPlannerTests/DesignSystem/PaperTemplateTests.swift` (NEW)

**Interfaces:**
- Produces:
  - `enum PaperTemplate: String, CaseIterable, Sendable { case ruled, blank, dotGrid, grid }` with `displayName`, `showsRedMargin: Bool` (true only for `.ruled`).
  - `struct PaperBackground: View` — renders `PaperGrain` + template-specific ruling + conditional `RedMarginLine` + optional `HolePunches`; init `PaperBackground(showsHolePunches: Bool = true)`; reads `@Environment(\.paperTemplate)`.
  - `UserSettings.templateKey: String = "ruled"` + `var paperTemplate: PaperTemplate` accessor (mirror `paperFont` at ~:112–115).
  - `@Entry var paperTemplate: PaperTemplate = .ruled` + `.paperTemplate(_:)` modifier in `Environment+Paper.swift`.

- [ ] **Step 1: Write the failing tests**:

```swift
import XCTest
@testable import WeeklyPlanner

final class PaperTemplateTests: XCTestCase {
    func testCasesAndDisplayNames() {
        XCTAssertEqual(PaperTemplate.allCases.map(\.displayName),
                       ["Ruled", "Blank", "Dot grid", "Grid"])
        XCTAssertEqual(PaperTemplate.allCases.map(\.rawValue),
                       ["ruled", "blank", "dotGrid", "grid"])
    }

    func testOnlyRuledShowsRedMargin() {
        XCTAssertTrue(PaperTemplate.ruled.showsRedMargin)
        XCTAssertFalse(PaperTemplate.blank.showsRedMargin)
        XCTAssertFalse(PaperTemplate.dotGrid.showsRedMargin)
        XCTAssertFalse(PaperTemplate.grid.showsRedMargin)
    }

    func testUserSettingsTemplateAccessorDefaultsToRuledAndRoundTrips() {
        let settings = UserSettings()
        XCTAssertEqual(settings.paperTemplate, .ruled)
        settings.paperTemplate = .dotGrid
        XCTAssertEqual(settings.templateKey, "dotGrid")
        settings.templateKey = "garbage"
        XCTAssertEqual(settings.paperTemplate, .ruled, "unknown raw falls back to ruled")
    }
}
```

- [ ] **Step 2: Run to verify failure.** Expected: compile failure.

- [ ] **Step 3: Implement** `PaperTemplate.swift`:

```swift
import SwiftUI

/// Selectable page background (Phase 44 #59 #78). Raw value is persisted
/// in `UserSettings.templateKey`.
enum PaperTemplate: String, CaseIterable, Sendable {
    case ruled
    case blank
    case dotGrid
    case grid

    var displayName: String {
        switch self {
        case .ruled: "Ruled"
        case .blank: "Blank"
        case .dotGrid: "Dot grid"
        case .grid: "Grid"
        }
    }

    /// The red margin line belongs to the ruled-notebook look only.
    var showsRedMargin: Bool { self == .ruled }
}
```

`PaperBackground.swift`:

```swift
import SwiftUI

/// The single paper stack every page uses (Phase 44). Replaces six
/// copy-pasted `ZStack { PaperGrain(); RuledLines(); RedMarginLine();
/// HolePunches() }` sites and branches on the selected template.
struct PaperBackground: View {
    var showsHolePunches = true
    @Environment(\.paperTemplate) private var template

    var body: some View {
        ZStack {
            PaperGrain()
            switch template {
            case .ruled: RuledLines()
            case .blank: EmptyView()
            case .dotGrid: DotGrid()
            case .grid: GridLines()
            }
            if template.showsRedMargin {
                RedMarginLine()
            }
            if showsHolePunches {
                HolePunches()
            }
        }
    }
}
```

⚠️ Before writing this, read ONE existing site (`DayPageView.swift:146-149`) — if the ZStack there orders/parameterizes the primitives differently (paddings, `allowsHitTesting`), reproduce that exactly; the refactor must be pixel-neutral for `.ruled`. `DotGrid`/`GridLines` don't exist yet — for THIS task stub them as `EmptyView`-bodied placeholders is a plan failure; instead implement them in Task 4 and keep this task compiling by writing the real Canvas views there first if you prefer a single commit. Recommended order: Task 3 Step 3 implements enum + settings + env only; the `PaperBackground` switch lands in Task 4 together with the two new Canvas primitives. If so, this task's sites-sweep moves to Task 4 — keep the checklist below with Task 4.

`UserSettings.swift` — stored `var templateKey: String = "ruled"` (+ init param, property-level default) and:

```swift
    var paperTemplate: PaperTemplate {
        get { PaperTemplate(rawValue: templateKey) ?? .ruled }
        set { templateKey = newValue.rawValue }
    }
```

`Environment+Paper.swift` — `@Entry var paperTemplate: PaperTemplate = .ruled` plus a `.paperTemplate(_:)` modifier matching the neighbors. `AppShell.swift` — add `resolvedTemplate` beside `resolvedTheme/Font/Size` (~:59–61) and inject `.paperTemplate(resolvedTemplate)` beside the others (~:140–142).

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/PaperTemplateTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/ WeeklyPlannerTests/DesignSystem/PaperTemplateTests.swift
git commit -m "feat(paper): PaperTemplate setting + environment plumbing (Phase 44 #59 #78)"
```

---

### Task 4: Dot-grid + grid primitives, `PaperBackground` switch, site sweep

**Files:**
- Create: `WeeklyPlanner/DesignSystem/Primitives/DotGrid.swift`, `GridLines.swift`
- Create/finish: `WeeklyPlanner/DesignSystem/Primitives/PaperBackground.swift` (Task 3 shape)
- Modify: every ruling site from the Task 3 re-grep
- Test: extend `PaperTemplateTests`

- [ ] **Step 1: Implement the primitives** — mirror `RuledLines.swift`'s Canvas structure (spacing constant, `theme.rule` color, 1pt strokes):

```swift
import SwiftUI

/// Dot-grid paper (Phase 44). Same 28pt rhythm as `RuledLines` so page
/// content lines up regardless of template.
struct DotGrid: View {
    @Environment(\.paperTheme) private var theme
    private let spacing: CGFloat = 28
    private let dotRadius: CGFloat = 1.1

    var body: some View {
        Canvas { context, size in
            var y = spacing
            while y < size.height {
                var x = spacing
                while x < size.width {
                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius,
                                      width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(theme.rule))
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}
```

```swift
import SwiftUI

/// Square-grid paper (Phase 44). 28pt cells, vertical lines drawn softer
/// so text rows still dominate.
struct GridLines: View {
    @Environment(\.paperTheme) private var theme
    private let spacing: CGFloat = 28

    var body: some View {
        Canvas { context, size in
            var y = spacing
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(theme.rule), lineWidth: 1)
                y += spacing
            }
            var x = spacing
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(theme.ruleSoft), lineWidth: 1)
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }
}
```

⚠️ Copy `RuledLines.swift`'s exact Canvas idioms (it may start at a top offset, use `theme.rule` vs `ruleSoft`, or set `.opacity`) — consistency beats this sketch.

- [ ] **Step 2: Sweep the sites.** Replace each `ZStack { PaperGrain(); RuledLines(); RedMarginLine(); HolePunches() }` block with `PaperBackground()` (pass `showsHolePunches: false` where a site omits `HolePunches` today — check each). Sites: `DayPageView`, `WeekPageView`, `PaperSettingsView`, `PaperNotesView`, `AISearchPaperSheet`, and `PaperReviewView` only if Phase 45 hasn't deleted it.

- [ ] **Step 3: Pixel-neutrality check.** Build & run; screenshot Day page before/after this branch at `.ruled` and diff visually. Any drift = the `PaperBackground` composition is wrong; fix before proceeding.

- [ ] **Step 4: Run** full unit suite (`-only-testing:WeeklyPlannerTests`). Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/
git commit -m "feat(paper): blank/dot-grid/grid templates behind unified PaperBackground (Phase 44 #59 #78)"
```

---

### Task 5: Four new fonts

**Files:**
- Add: `WeeklyPlanner/Resources/Fonts/Handlee-Regular.ttf`, `ComicNeue-Regular.ttf`, `ComicNeue-Bold.ttf`, `Mali-Regular.ttf`, `Mali-Bold.ttf`, `AnnieUseYourTelescope-Regular.ttf`
- Modify: `WeeklyPlanner/Supporting/Info.plist` (`UIAppFonts`, ~lines 71–86), `WeeklyPlanner/DesignSystem/PaperFont.swift`
- Add: OFL license texts under `licenses/` (one file per family); Modify: `README.md` font-licensing note
- Test: `WeeklyPlannerTests/DesignSystem/PaperFontRegistrationTests.swift`, `PaperSettingsViewTests.swift`

The four families (all OFL, downloadable from Google Fonts; pick the latest release TTFs): **Handlee** (neat rounded print — the "more legible" option), **Comic Neue** (clean casual, has a real Bold), **Mali** (soft print, has a real Bold), **Annie Use Your Telescope** (tall airy handwriting). If a family proves unavailable, substitute another OFL handwriting family and note the deviation.

- [ ] **Step 1: Update the failing tests.** `PaperFontRegistrationTests`: count 8 → 12 in `testAllCasesIncludeTheFourNewFamilies` (rename to reflect twelve), keep `testEveryFamilyResolvesItsRegularFace` — it will fail until PS names are right, which is the point. `PaperSettingsViewTests`: font-count guard 8 → 12 (`testPaperFontCountIsEightSoFontCardsGridIsFourFullRows` → twelve/updated row math).

- [ ] **Step 2: Bundle.** Download TTFs into `Resources/Fonts/`; add the six filenames to `Info.plist` `UIAppFonts`; drop each family's `OFL.txt` into `licenses/<Family>-OFL.txt`; run `xcodegen generate`.

- [ ] **Step 3: Extend `PaperFont`** — add cases `handlee, comicNeue, mali, annie` with `displayName` ("Handlee", "Comic Neue", "Mali", "Annie") and `postScriptName(for:)` mappings. **Verify real PostScript names first**:

```bash
fc-scan --format "%{postscriptname}\n" WeeklyPlanner/Resources/Fonts/Handlee-Regular.ttf   # or: mdls -name com_apple_ats_name_postscript
```

(or run the registration test and read the failure). Multi-weight families (Comic Neue, Mali) get a name-mapper like `kalamName` (`PaperFont.swift:99-105`); single-weight ones return their one face. Update `weightFor(legibility:)` if the file's pattern requires an entry per family.

- [ ] **Step 4: Run to verify pass** — `-only-testing:WeeklyPlannerTests/PaperFontRegistrationTests -only-testing:WeeklyPlannerTests/PaperFontTests -only-testing:WeeklyPlannerTests/TypographyTests -only-testing:WeeklyPlannerTests/PaperSettingsViewTests`. Expected: PASS (`testFontResolvesForEveryHandwritingFamily` now covers 12).

- [ ] **Step 5: Update `README.md`** font-licensing section (bottom of file) with the four families + OFL pointers. **Commit**

```bash
git add WeeklyPlanner/ licenses/ README.md WeeklyPlannerTests/
git commit -m "feat(fonts): Handlee, Comic Neue, Mali, Annie (OFL) — 12 families (Phase 44 #78)"
```

---

### Task 6: Settings restructure — Theme out, Font + Paper in

**Files:**
- Modify: `WeeklyPlanner/Features/Settings/PaperSettingsView.swift` (`sections(for:)`, ~lines 54–108)
- Delete: `WeeklyPlanner/Features/Settings/ThemeCardsGrid.swift`, `ThemeCard.swift`
- Create: `WeeklyPlanner/Features/Settings/PaperCardsGrid.swift`
- Modify: `WeeklyPlanner/Features/Settings/SettingsViewModel.swift`, `WeeklyPlanner/Navigation/AppShell.swift` (cream migration)
- Test: `SettingsViewModelTests.swift`, `PaperSettingsViewTests.swift`

- [ ] **Step 1: Write the failing tests.**

`SettingsViewModelTests` (append/replace theme tests):

```swift
    func testSelectingTemplatePersists() throws {
        let vm = SettingsViewModel(store: store)
        vm.setTemplate(.dotGrid)
        XCTAssertEqual(vm.template, .dotGrid)
        XCTAssertEqual(try store.current().paperTemplate, .dotGrid)
    }

    func testLegacyNonCreamThemeMigratesToCream() throws {
        try store.update { $0.themeKey = "midnight" }
        // AppShell.migrateThemeIfNeeded is the single migration entry point.
        AppShell.migrateThemeIfNeeded(store: store)
        XCTAssertEqual(try store.current().paperTheme, .cream)
    }
```

Delete `testSelectingThemePersists` (picker gone; `setTheme` removed). In `PaperSettingsViewTests`: delete `testPaperThemeKeyCountMatchesGridColumnCount`; add a guard that `PaperTemplate.allCases.count == 4`.

- [ ] **Step 2: Run to verify failure.** Expected: compile failure (`setTemplate` missing).

- [ ] **Step 3: Implement.**

`SettingsViewModel` — add `var template: PaperTemplate` (init from `settings.paperTemplate`) and:

```swift
    func setTemplate(_ template: PaperTemplate) {
        self.template = template
        try? store.update { $0.paperTemplate = template }
    }
```

Remove `theme`/`setTheme` and fix references.

`AppShell` — one-time migration (call where settings are first resolved):

```swift
    /// Phase 44: the theme picker is gone; the app ships Cream. Migrate
    /// legacy kraft/midnight rows so stored state matches the UI.
    static func migrateThemeIfNeeded(store: any SettingsStoring) {
        guard let current = try? store.current(), current.paperTheme != .cream else { return }
        try? store.update { $0.paperTheme = .cream }
    }
```

`resolvedTheme` simplifies to `.cream.theme` (keep the property so the environment injection line is untouched).

`PaperSettingsView.sections(for:)` — delete the Theme block (`SectionTitle("Theme"…)` + `ThemeCardsGrid`, ~:57–58); retitle `SectionTitle("Handwriting")` → `SectionTitle("Font")` (~:61); insert after the Font grid:

```swift
            SectionTitle("Paper")
            PaperCardsGrid(selection: viewModel.template) { viewModel.setTemplate($0) }
```

`PaperCardsGrid.swift` — clone `FontCardsGrid`/`FontCard`'s card chrome; each card draws a mini page preview of its template (a 44×56 rounded rect containing a scaled-down `RuledLines`/`DotGrid`/`GridLines`/nothing) + `displayName` caption; a11y id `AccessibilityIDs.settingsPaperCard(_ template.rawValue)` (add helper beside `settingsFontCard`).

- [ ] **Step 4: Delete** `ThemeCardsGrid.swift` + `ThemeCard.swift`; sweep `grep -rn "ThemeCard\|setTheme(" WeeklyPlanner/ WeeklyPlannerTests/` and fix stragglers (incl. `PaperThemeTests` if it referenced the cards — theme TYPE tests stay).

- [ ] **Step 5: Run** — `-only-testing:WeeklyPlannerTests/SettingsViewModelTests -only-testing:WeeklyPlannerTests/PaperSettingsViewTests -only-testing:WeeklyPlannerTests/PaperThemeTests`, then `xcodegen generate` + full unit suite. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(settings): drop Theme picker (cream locked), Font + Paper sections (Phase 44 #77 #78 #59)"
```

---

### Task 7: Full verification (superpowers:verification-before-completion)

- [ ] **Step 1: Full unit suite.** Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 2: UI smoke suites** — `SmokeUITests` + the settings-related UI suites (`grep -l "settings" WeeklyPlannerUITests/`). Expected: PASS.
- [ ] **Step 3: Signed-sim manual pass:** XXL size legible on Day/Week/sheet; date caption visibly bigger; each paper template renders on Day/Week/Notes/Settings/Ask sheet; red margin only on Ruled; all 12 fonts render (no  tofu / fallback-serif cards); no Theme section; Connections untouched.
- [ ] **Step 4: Phase-doc checklist sweep** — `docs/phases/phase-44-typography-paper-expansion.md`.
- [ ] **Step 5: Report** — branch, diffstat, per-header scale decisions from Task 2, any font substitutions.

---

## Self-review notes

- **Spec coverage:** #58/#79 (T1, T2), #62 (T2), #59/#78-paper (T3, T4, T6), #78-fonts (T5), #77 (T6).
- **Type consistency:** `PaperTemplate` rawValues match `templateKey` strings and `settingsPaperCard` ids; `setTemplate(_:)`/`template` names identical T6 tests↔impl; scale literals identical T1 test↔impl.
- **Deliberate choices:** templates keep the 28pt rhythm so content alignment is template-independent; theme type retained (30 color tokens ripple everywhere — only the picker dies); cream migration is one-way and idempotent; new sizes are additive so `sizeKey` needs no migration.
- **Sequencing:** T3+T4 may merge into one commit if the implementer prefers real primitives before the switch (flagged inline); everything else is order-independent after T1.
