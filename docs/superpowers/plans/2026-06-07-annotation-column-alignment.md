# Annotation Column Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Long-press notes on the Day page land with their leading edge on the event column at the line you pressed, instead of drifting ~110 pt left into the margin.

**Architecture:** Re-anchor the annotation layer from center (`.position`) to top-leading (`.offset`) so `unitX/unitY` address a note's top-left corner; compute new-note placement through a small pure `DayPageLayout` helper that snaps X to the page margin and keeps Y at the press point; lift the repeated `44` page-margin literal into that helper so the column and the page margin can't drift.

**Tech Stack:** Swift / SwiftUI, SwiftData (`@Model Annotation`), XCTest, XcodeGen (`project.yml`, folder-globbed sources), iOS Simulator.

**Spec:** `docs/superpowers/specs/2026-06-07-annotation-column-alignment-design.md`

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `WeeklyPlanner/Features/DayPage/DayPageLayout.swift` | Shared day-page geometry: `pageMargin` constant + pure `annotationCreationUnit(pressY:layerSize:)` placement helper | Create |
| `WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift` | Unit tests for the placement helper | Create |
| `WeeklyPlanner/Features/DayPage/Annotations/AnnotationLayer.swift` | Render notes top-leading-anchored (`.position` → `.offset`) | Modify (`AnnotationLayer.swift:22-29`) |
| `WeeklyPlanner/Features/DayPage/DayPageView.swift` | Use the column-aligned creation unit in the long-press gesture; adopt `pageMargin` in the page padding | Modify (`DayPageView.swift:147`, `:337-343`) |

**Conventions captured from the codebase:**
- `Annotation.clampUnit(_ point: CGPoint) -> CGPoint` clamps to 0…1 and recovers non-finite (NaN/inf) inputs to `0.5` (`Annotation.swift:53`). It is the only NaN/inf guard the helper needs.
- `DayPageViewModel.addAnnotation(atUnit point: CGPoint) async -> Annotation?` stores the unit it is handed verbatim (`DayPageViewModel.swift:324`) — unchanged by this work.
- New files under `WeeklyPlanner/` and `WeeklyPlannerTests/` are auto-included by XcodeGen's folder globbing; regenerate the project after adding them.

**Test/destination commands used throughout** (substitute any available iPhone simulator from `xcrun simctl list devices available`; if the name is ambiguous across runtimes, append `,OS=26.4` or use the device UDID; if a simulator signing error appears, append `CODE_SIGNING_ALLOWED=NO`):

```bash
DEST='platform=iOS Simulator,name=iPhone 17'
```

---

## Task 1: `DayPageLayout` placement helper (TDD)

**Files:**
- Create: `WeeklyPlanner/Features/DayPage/DayPageLayout.swift`
- Test: `WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift`

- [ ] **Step 1: Write the failing test**

Create `WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift`:

```swift
import CoreGraphics
import XCTest
@testable import WeeklyPlanner

final class DayPageLayoutTests: XCTestCase {

    func testNewAnnotationLeadingEdgeLandsOnPageMargin() {
        let layer = CGSize(width: 400, height: 800)
        let unit = DayPageLayout.annotationCreationUnit(pressY: 300, layerSize: layer)

        // Leading edge sits exactly on the event column (the page margin)…
        XCTAssertEqual(unit.x * layer.width, DayPageLayout.pageMargin, accuracy: 0.0001)
        // …and the vertical position is preserved at the press point.
        XCTAssertEqual(unit.y * layer.height, 300, accuracy: 0.0001)
    }

    func testHorizontalPressIsIrrelevantToColumn() {
        // The helper takes no press-X by design; the column is constant
        // regardless of layer width, so two widths still map x back to margin.
        let narrow = DayPageLayout.annotationCreationUnit(pressY: 100, layerSize: CGSize(width: 320, height: 600))
        let wide = DayPageLayout.annotationCreationUnit(pressY: 100, layerSize: CGSize(width: 800, height: 600))

        XCTAssertEqual(narrow.x * 320, DayPageLayout.pageMargin, accuracy: 0.0001)
        XCTAssertEqual(wide.x * 800, DayPageLayout.pageMargin, accuracy: 0.0001)
    }

    func testDegenerateLayerSizeStaysInUnitRange() {
        let unit = DayPageLayout.annotationCreationUnit(pressY: 120, layerSize: .zero)

        XCTAssertTrue(unit.x.isFinite && unit.x >= 0 && unit.x <= 1)
        XCTAssertTrue(unit.y.isFinite && unit.y >= 0 && unit.y <= 1)
    }
}
```

- [ ] **Step 2: Regenerate the project so the new test file is in the target**

Run: `xcodegen generate`
Expected: `Created project at WeeklyPlanner.xcodeproj` (no errors).

- [ ] **Step 3: Run the test to verify it fails**

Run:
```bash
xcodebuild test -scheme WeeklyPlanner -destination "$DEST" \
  -only-testing:WeeklyPlannerTests/DayPageLayoutTests 2>&1 | tail -30
```
Expected: COMPILE FAILURE — `cannot find 'DayPageLayout' in scope`.

- [ ] **Step 4: Write the minimal implementation**

Create `WeeklyPlanner/Features/DayPage/DayPageLayout.swift`:

```swift
import CoreGraphics

/// Day-page geometry shared between the page chrome and the annotation
/// creation gesture, so the annotation column can never drift from the
/// page's leading margin.
enum DayPageLayout {
    /// Leading page margin — the red rule line where events, to-dos, and the
    /// annotation column all begin.
    static let pageMargin: CGFloat = 44

    /// Unit-space (0…1) position for a new long-press annotation: leading
    /// edge snapped to the event column (`pageMargin`), vertical position at
    /// the press point. Horizontal press position is intentionally ignored so
    /// every new note lines up in the same column. `Annotation.clampUnit` is
    /// the NaN/inf safety net for a degenerate (zero) layer size.
    static func annotationCreationUnit(pressY: CGFloat, layerSize: CGSize) -> CGPoint {
        Annotation.clampUnit(CGPoint(x: pageMargin / layerSize.width,
                                     y: pressY / layerSize.height))
    }
}
```

- [ ] **Step 5: Regenerate so the new source file is in the app target**

Run: `xcodegen generate`
Expected: success, no errors.

- [ ] **Step 6: Run the test to verify it passes**

Run:
```bash
xcodebuild test -scheme WeeklyPlanner -destination "$DEST" \
  -only-testing:WeeklyPlannerTests/DayPageLayoutTests 2>&1 | tail -30
```
Expected: `Test Suite 'DayPageLayoutTests' passed` — 3 tests, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageLayout.swift \
        WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(annotations): DayPageLayout helper — column-aligned creation unit"
```

---

## Task 2: Re-anchor the annotation layer to top-leading

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/Annotations/AnnotationLayer.swift:22-29`

There is no unit test for this step — SwiftUI layout is verified by the build, the unchanged annotation suites, and the manual pass in Task 4. `.offset` keeps each note's own size and shifts only its rendered/hit region; the host `ZStack(alignment: .topLeading)` already pins every child's origin to the layer's top-left, so an offset of `(width·unitX, height·unitY)` lands the note's top-left corner there. Empty paper stays interactive because the only hit shape is the inner `contentShape(Rectangle())` on the 220-pt text box (`AnnotationView.swift:67`); the offset adds no background.

- [ ] **Step 1: Swap `.position` for a top-leading `.offset`**

Replace (`AnnotationLayer.swift:22-29`):

```swift
                ForEach(viewModel.annotations, id: \.id) { annotation in
                    AnnotationView(annotation: annotation,
                                   layerSize: geo.size,
                                   editingID: $editingID,
                                   viewModel: viewModel)
                        .position(x: geo.size.width * annotation.unitX,
                                  y: geo.size.height * annotation.unitY)
                }
```

with:

```swift
                ForEach(viewModel.annotations, id: \.id) { annotation in
                    AnnotationView(annotation: annotation,
                                   layerSize: geo.size,
                                   editingID: $editingID,
                                   viewModel: viewModel)
                        // Top-leading anchor: unitX/unitY address the note's
                        // top-left corner (not its center), so its leading edge
                        // lands exactly where the unit position maps. The host
                        // ZStack is `.topLeading`, so each note starts at the
                        // layer origin and this offset shifts its corner. Drag
                        // is unaffected — `moveGesture` is translation-based.
                        .offset(x: geo.size.width * annotation.unitX,
                                y: geo.size.height * annotation.unitY)
                }
```

- [ ] **Step 2: Build and run the existing annotation suites to confirm no regression**

Run:
```bash
xcodebuild test -scheme WeeklyPlanner -destination "$DEST" \
  -only-testing:WeeklyPlannerTests/AnnotationLayerTests \
  -only-testing:WeeklyPlannerTests/AnnotationStoreTests \
  -only-testing:WeeklyPlannerTests/AnnotationFlipSuppressionTests 2>&1 | tail -30
```
Expected: all three suites pass (they exercise the view model / store, not pixel layout, so the anchor change does not affect them).

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/Annotations/AnnotationLayer.swift
git commit -m "fix(annotations): top-leading anchor so notes land where placed"
```

---

## Task 3: Column-align creation + adopt the page-margin constant

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift:337-343` (gesture placement math)
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift` — all three `.padding(.leading, 44)` sites (line 147 scroll content, 371 EventAddRow, 388 TodoBlock) → `DayPageLayout.pageMargin`. (Expanded from the original single-site scope after the Task 1 review found three identical sites; migrating all three realizes the dedup and prevents drift.)

- [ ] **Step 1: Use the column-aligned creation unit in the long-press handler**

Replace (`DayPageView.swift:337-343`):

```swift
                // `startLocation`, intentionally: the annotation anchors where
                // the press began, not wherever the finger drifted by lift-off.
                // `annotationLayerSize` mirrors AnnotationLayer's geo.size (same
                // node) — captured separately because this gesture fires outside
                // the layer's GeometryReader scope.
                let unit = CGPoint(x: drag.startLocation.x / annotationLayerSize.width,
                                   y: drag.startLocation.y / annotationLayerSize.height)
```

with:

```swift
                // X is column-aligned (not the press X): new notes line up at
                // the event column. Y follows the press so the note starts on
                // the line under the finger. `startLocation`, intentionally:
                // anchored where the press began, not where the finger drifted.
                // `annotationLayerSize` mirrors AnnotationLayer's geo.size (same
                // node) — captured separately because this gesture fires outside
                // the layer's GeometryReader scope.
                let unit = DayPageLayout.annotationCreationUnit(
                    pressY: drag.startLocation.y,
                    layerSize: annotationLayerSize)
```

- [ ] **Step 2: Adopt the named page-margin constant at all three page-margin sites**

There are exactly three identical `.padding(.leading, 44)` occurrences in this file — the scroll content (~line 147, the annotation column), `EventAddRow` (~line 371), and `TodoBlock` (~line 388). All three are the same page margin, so replace every occurrence:

```swift
                                .padding(.leading, 44)
```

with:

```swift
                                .padding(.leading, DayPageLayout.pageMargin)
```

(Use a replace-all on the exact string `.padding(.leading, 44)`. First confirm there are exactly three matches and each is a leading page margin; if the count differs, stop and report.)

- [ ] **Step 3: Build and run the full unit-test suite**

Run:
```bash
xcodebuild test -scheme WeeklyPlanner -destination "$DEST" \
  -only-testing:WeeklyPlannerTests 2>&1 | tail -30
```
Expected: BUILD SUCCEEDED, `Test Suite 'WeeklyPlannerTests' passed`, 0 failures (includes the new `DayPageLayoutTests`).

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageView.swift
git commit -m "fix(annotations): long-press notes align to the event column"
```

---

## Task 4: Regression + manual verification

**Files:** none (verification only).

- [ ] **Step 1: Run the annotation UI tests**

Run:
```bash
xcodebuild test -scheme WeeklyPlanner -destination "$DEST" \
  -only-testing:WeeklyPlannerUITests/AnnotationsUITests 2>&1 | tail -40
```
Expected: PASS. These assert that a long-press creates an editable note and that aborted drags don't break navigation — not an exact pixel X — so the anchor/column change should not break them. If an assertion did encode the old center anchor (e.g. a hard-coded tap coordinate to re-hit the created note), update it to the note's new top-leading location and re-run.

- [ ] **Step 2: Manual check on the simulator**

Run the app (`xcodebuild build` then launch, or open in Xcode and Run). On a Day page:
1. Long-press several different spots — left margin, middle, right side, top, and bottom of the page.
2. Confirm each created note's **leading edge sits on the event column** (aligned with "add your first event" and the red margin line), at the **vertical line you pressed** — never drifting left into the margin.
3. Confirm you can still **drag** a note freely afterward, and the page does **not** flip mid-drag.
4. Confirm tapping a note still opens its editor and empty paper still scrolls / accepts long-press.

- [ ] **Step 3: Mark the spec/plan done (optional bookkeeping)**

If the project tracks status in `docs/phases` or similar, note this follow-up as shipped. No code change.

---

## Notes / out of scope

- **Pre-existing notes shift once.** A note created before Task 2 had its unit stored as a center; it now reads as a top-left, so it shifts right ~110 pt / down ~half its height on first render. Accepted (feature is one day old, notes are user-repositionable).
- **Drag to the far right edge** can now push a note's top-left to the edge and mostly off-screen (top-left vs. old center anchor). Constraining drag to the column is explicitly out of scope (per spec).
- **Add Event sheet** is unchanged — long-press → annotation is the confirmed desired behavior; event creation stays on the existing "add your first event" row.
