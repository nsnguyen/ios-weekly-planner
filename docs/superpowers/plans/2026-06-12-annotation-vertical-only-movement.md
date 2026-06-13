# Annotation Vertical-Only, Left-Locked Movement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Day-page notes become an ordered, left-aligned list — drag is vertical-only and every note renders flush at the page margin.

**Architecture:** Make `DayPageLayout.pageMargin` the single source of truth for a note's horizontal position. A new pure helper computes the vertical-drag destination (X always on the margin); `AnnotationView` routes its drag through it and stops feeding horizontal translation into the live offset; `AnnotationLayer` renders the X at the margin constant, so stored `unitX` no longer drives the column (it self-heals on the next drag — no data migration).

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest. Build/test via `xcodebuild` against the iPhone 17 Pro simulator.

**Spec:** `docs/superpowers/specs/2026-06-12-annotation-vertical-only-movement-design.md`

---

## Pre-flight: branch

Feature code must not land directly on `main`. Before Task 1:

```bash
git checkout -b annotation-vertical-only
```

All four files already exist in the Xcode project, so **no `xcodegen generate` is needed** (no files are created).

## File Structure

| File | Responsibility | Change |
|------|----------------|--------|
| `WeeklyPlanner/Features/DayPage/DayPageLayout.swift` | Pure day-page geometry (testable without SwiftUI) | Add `verticalDragUnit(currentUnitY:translationHeight:layerSize:)` |
| `WeeklyPlanner/Features/DayPage/Annotations/AnnotationView.swift` | One note's display/edit/drag | `dragOffset` → Y-only; `onEnded` → `verticalDragUnit` |
| `WeeklyPlanner/Features/DayPage/Annotations/AnnotationLayer.swift` | Positions all notes in the overlay | Render X at `pageMargin` (ignore stored `unitX`) |
| `WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift` | Unit tests for pure geometry | Add `verticalDragUnit` tests |

---

## Task 1: Pure `verticalDragUnit` helper (TDD)

**Files:**
- Test: `WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift`
- Modify: `WeeklyPlanner/Features/DayPage/DayPageLayout.swift`

- [ ] **Step 1: Write the failing tests**

Append inside the `DayPageLayoutTests` class (before the closing `}` at line 172):

```swift
    // MARK: - Vertical-only drag destination

    func testVerticalDragKeepsLeadingEdgeOnTheMargin() {
        let layer = CGSize(width: 400, height: 800)
        let unit = DayPageLayout.verticalDragUnit(currentUnitY: 0.5,
                                                  translationHeight: 0,
                                                  layerSize: layer)
        // X always lands on the page margin — the helper takes no starting X.
        XCTAssertEqual(unit.x * layer.width, DayPageLayout.pageMargin, accuracy: 0.0001)
        XCTAssertEqual(unit.y, 0.5, accuracy: 0.0001)
    }

    func testVerticalDragMovesYByTranslationOnly() {
        let layer = CGSize(width: 400, height: 800)
        // Start at 400pt (0.5), drag down 80pt → 480pt; X stays on the margin.
        let unit = DayPageLayout.verticalDragUnit(currentUnitY: 0.5,
                                                  translationHeight: 80,
                                                  layerSize: layer)
        XCTAssertEqual(unit.y * layer.height, 480, accuracy: 0.0001)
        XCTAssertEqual(unit.x * layer.width, DayPageLayout.pageMargin, accuracy: 0.0001)
    }

    func testVerticalDragUpwardClampsAtPageTop() {
        let layer = CGSize(width: 400, height: 800)
        // From 80pt (0.1), drag up 200pt → −120pt, floored to the top.
        let unit = DayPageLayout.verticalDragUnit(currentUnitY: 0.1,
                                                  translationHeight: -200,
                                                  layerSize: layer)
        XCTAssertEqual(unit.y, 0, accuracy: 0.0001)
        XCTAssertEqual(unit.x * layer.width, DayPageLayout.pageMargin, accuracy: 0.0001)
    }

    func testVerticalDragDownwardClampsAtPageBottom() {
        let layer = CGSize(width: 400, height: 800)
        // From 720pt (0.9), drag down 200pt → 920pt (1.15), clamped to 1.
        let unit = DayPageLayout.verticalDragUnit(currentUnitY: 0.9,
                                                  translationHeight: 200,
                                                  layerSize: layer)
        XCTAssertEqual(unit.y, 1, accuracy: 0.0001)
        XCTAssertEqual(unit.x * layer.width, DayPageLayout.pageMargin, accuracy: 0.0001)
    }

    func testVerticalDragDegenerateLayerStaysInUnitRange() {
        // Guarded out in the gesture, but the helper must stay finite on a
        // zero layer — mirrors testDegenerateLayerSizeStaysInUnitRangeForStacking.
        let unit = DayPageLayout.verticalDragUnit(currentUnitY: 0.5,
                                                  translationHeight: 40,
                                                  layerSize: .zero)
        XCTAssertTrue(unit.x.isFinite && unit.x >= 0 && unit.x <= 1)
        XCTAssertTrue(unit.y.isFinite && unit.y >= 0 && unit.y <= 1)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/DayPageLayoutTests \
  CODE_SIGNING_ALLOWED=NO
```
Expected: **build failure** — `type 'DayPageLayout' has no member 'verticalDragUnit'`. (In a compiled language the missing symbol is the red test.)

- [ ] **Step 3: Implement the helper**

In `DayPageLayout.swift`, add this immediately after `stackedAnnotationUnit(...)` (after line 40, before the `AnnotationNudge` struct):

```swift
    /// Unit-space destination for a vertical-only note drag: the leading
    /// edge stays locked to the page margin (notes form a single
    /// left-aligned column), and only the top's Y moves by the drag
    /// translation. The starting X is intentionally not a parameter — it is
    /// always the margin. `Annotation.clampUnit` keeps the note on the page
    /// and is the NaN/inf safety net for a degenerate (zero) layer size,
    /// mirroring `stackedAnnotationUnit`.
    static func verticalDragUnit(currentUnitY: Double,
                                 translationHeight: CGFloat,
                                 layerSize: CGSize) -> CGPoint {
        Annotation.clampUnit(CGPoint(
            x: pageMargin / layerSize.width,
            y: CGFloat(currentUnitY) + translationHeight / layerSize.height))
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/DayPageLayoutTests \
  CODE_SIGNING_ALLOWED=NO
```
Expected: **TEST SUCCEEDED** — all `DayPageLayoutTests` pass (5 new + 12 existing).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageLayout.swift \
        WeeklyPlannerTests/Annotations/DayPageLayoutTests.swift
git commit -m "feat(annotations): pure verticalDragUnit — margin-locked X, Y from translation

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Constrain the drag in `AnnotationView`

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/Annotations/AnnotationView.swift:80-100` (the `moveGesture` computed property)

No new unit test: the math now lives in the Task 1 helper (a SwiftUI gesture closure isn't independently unit-testable — that is exactly why the math was extracted). Verification is a clean build plus the unchanged full suite.

- [ ] **Step 1: Constrain the live drag offset to vertical**

Replace the `.updating($dragOffset)` block (lines 82–84):

```swift
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
```

with:

```swift
            .updating($dragOffset) { value, state, _ in
                // Vertical-only: drop the horizontal component so the note
                // tracks the finger up/down and never drifts off its column.
                state = CGSize(width: 0, height: value.translation.height)
            }
```

- [ ] **Step 2: Pin the commit to the margin, move only Y**

Replace the `.onEnded` block (lines 88–99):

```swift
            .onEnded { value in
                guard layerSize.width > 0, layerSize.height > 0 else { return }
                let newUnit = Annotation.clampUnit(CGPoint(
                    x: annotation.unitX + value.translation.width / layerSize.width,
                    y: annotation.unitY + value.translation.height / layerSize.height))
                // Commit the position to the live model in the same render
                // transaction that resets `dragOffset`, so the view never
                // flashes back to its pre-drag spot while persistence runs.
                annotation.unitX = newUnit.x
                annotation.unitY = newUnit.y
                Task { await viewModel.moveAnnotation(id: annotation.id, toUnit: newUnit) }
            }
```

with:

```swift
            .onEnded { value in
                guard layerSize.width > 0, layerSize.height > 0 else { return }
                // Vertical-only: leading edge stays on the margin, only Y moves.
                // Re-bases on the live (possibly nudged) unitY plus the
                // translation, so the on-screen release position wins.
                let newUnit = DayPageLayout.verticalDragUnit(
                    currentUnitY: annotation.unitY,
                    translationHeight: value.translation.height,
                    layerSize: layerSize)
                // Commit to the live model in the same render transaction that
                // resets `dragOffset`, so the view never flashes back to its
                // pre-drag spot while persistence runs. Writing the margin X
                // here also self-heals any stale stored unitX on first drag.
                annotation.unitX = newUnit.x
                annotation.unitY = newUnit.y
                Task { await viewModel.moveAnnotation(id: annotation.id, toUnit: newUnit) }
            }
```

- [ ] **Step 3: Build to verify it compiles**

Run:
```bash
xcodebuild build \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO
```
Expected: **BUILD SUCCEEDED**.

- [ ] **Step 4: Run the annotation suites to verify nothing regressed**

Run:
```bash
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/DayPageLayoutTests \
  -only-testing:WeeklyPlannerTests/AnnotationLayerTests \
  -only-testing:WeeklyPlannerTests/AnnotationStoreTests \
  CODE_SIGNING_ALLOWED=NO
```
Expected: **TEST SUCCEEDED**. (`testMoveClampsAndPersists` still passes — `moveAnnotation` is unchanged and still clamps/persists whatever unit it's handed.)

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/Annotations/AnnotationView.swift
git commit -m "feat(annotations): drag is vertical-only — X pinned to the margin

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Lock the rendered X to the margin in `AnnotationLayer`

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/Annotations/AnnotationLayer.swift:47-54` (the anchor comment + `.offset`)

This is the change that snaps **all** notes — including any dragged off to the right under the old behavior — to the column, since render stops reading stored `unitX`.

- [ ] **Step 1: Render X at the margin constant**

Replace the comment + offset block (lines 47–54):

```swift
                        // Top-leading anchor: unitX/unitY address the note's
                        // top-left corner (not its center), so its leading edge
                        // lands exactly where the unit position maps. The host
                        // ZStack is `.topLeading`, so each note starts at the
                        // layer origin and this offset shifts its corner. Drag
                        // is unaffected — `moveGesture` is translation-based.
                        .offset(x: geo.size.width * annotation.unitX,
                                y: geo.size.height * annotation.unitY)
```

with:

```swift
                        // Vertical-only, left-locked: the leading edge is pinned
                        // to the page margin so every note forms one left-aligned
                        // column. Stored `unitX` no longer drives X — a note
                        // dragged off-column under the old free-2D behavior snaps
                        // back here, and the value self-heals to the margin on its
                        // next drag (see verticalDragUnit). `unitY` still addresses
                        // the note's top edge against the `.topLeading` host ZStack.
                        .offset(x: DayPageLayout.pageMargin,
                                y: geo.size.height * annotation.unitY)
```

- [ ] **Step 2: Build to verify it compiles**

Run:
```bash
xcodebuild build \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO
```
Expected: **BUILD SUCCEEDED**.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/Annotations/AnnotationLayer.swift
git commit -m "feat(annotations): render every note flush at the left margin

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Full regression + on-simulator verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full unit-test suite**

Run:
```bash
xcodebuild test \
  -project WeeklyPlanner.xcodeproj \
  -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGNING_ALLOWED=NO
```
Expected: **TEST SUCCEEDED** — full unit suite green (no behavioral test depended on free horizontal drag).

- [ ] **Step 2: Lint**

Run:
```bash
swiftlint --strict && swiftformat --lint .
```
Expected: no violations.

- [ ] **Step 3: Manual verification on the simulator**

Boot the app, open a Day page, and confirm:
1. **Create** — long-press empty paper → a note appears at the left margin, stacked below existing content. (Unchanged.)
2. **Vertical-only** — drag an existing note: it tracks the finger up/down only and cannot be pulled left/right; on release it stays in its column at the new height.
3. **Snap-left** — if a note was previously dragged off to the right (pre-change data), it now renders flush at the margin. If no such note exists, this is satisfied by construction; note it as not-reproducible rather than claiming it passed.

Record the actual observed result for each (pass / fail / not-reproducible). Do **not** claim a visual check passed without having run the app.

> **Optional automated UI test (only if it proves stable):** In `WeeklyPlannerUITests/AnnotationsUITests.swift`, a test that creates a note, drags it down, and asserts `minX` is unchanged (Δ ≈ 0) while `minY` increased. Assert *relative* movement, not absolute coordinates — XCUI annotation frames carry documented accessibility-padding inflation. If it flakes across two runs, delete it and rely on Step 3; a flaky test is worse than none.

---

## Self-review notes

- **Spec coverage:** vertical-only live drag (Task 2 Step 1) + vertical-only commit (Task 2 Step 2, via Task 1 helper); all-notes-left at render (Task 3); margin = `pageMargin` (Tasks 1/3); no migration / self-heal (Task 2 Step 2 comment + Task 3 comment); creation/auto-nudge/pin/schema untouched (no task modifies them). All spec sections map to a task.
- **Type consistency:** `verticalDragUnit(currentUnitY: Double, translationHeight: CGFloat, layerSize: CGSize) -> CGPoint` is defined in Task 1 and called identically in Task 2. `unitX`/`unitY` are `Double`; `clampUnit` takes/returns `CGPoint` (`CGFloat`); the `CGFloat(currentUnitY)` cast and the `newUnit.x → unitX` (`CGFloat → Double`) assignment match the existing gesture's conventions.
- **No placeholders:** every code/command step is concrete.
