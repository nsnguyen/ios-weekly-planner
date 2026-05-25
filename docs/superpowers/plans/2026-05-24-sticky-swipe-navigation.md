# Sticky Swipe Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the clunky long-press → context menu → "Show another" as the primary way to navigate between AI sticky notes with a natural horizontal swipe gesture, plus page indicator dots.

**Architecture:** Add a `@State currentIndex` and horizontal `DragGesture` to `AIStickyStack`. The gesture is scoped to the top sticky's frame via `.highPriorityGesture` to avoid conflicts with the day-page flip (which uses `PageFlipContainer`, a separate 3D-flip view — not a `DragGesture` on the same hierarchy). The `onShowAnother` callback is replaced with `onNavigate: (Int) -> Void` that passes the new index. `DayPageView.promoteNextSticky()` becomes index-aware. Context menu "Show another" stays as a secondary path.

**Tech Stack:** SwiftUI (iOS 26+), `DragGesture`, `AnimationTokens`

**Spec:** `docs/phases/phase-24-ai-sticky-v2.md` (updated with swipe-to-navigate section)

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `WeeklyPlanner/Features/DayPage/AIStickyStack.swift` | MODIFY | Add `@State currentIndex`, `DragGesture`, swipe animation, page indicator dots. Replace `onShowAnother` with index-based navigation. |
| `WeeklyPlanner/Features/DayPage/DayPageView.swift:322-347` | MODIFY | Update `stickyNoteOverlay` and `promoteNextSticky` to work with index-based API. |
| `WeeklyPlanner/Accessibility/ReduceMotionAnimations.swift` | MODIFY | Add `stickySwipe(reduced:)` factory for the swipe transition. |
| `WeeklyPlannerTests/DayPage/AIStickyStackTests.swift` | MODIFY | Add swipe and page indicator tests. |

---

### Task 1: Add `stickySwipe` animation token

**Files:**
- Modify: `WeeklyPlanner/DesignSystem/AnimationTokens.swift`
- Modify: `WeeklyPlanner/Accessibility/ReduceMotionAnimations.swift`

- [ ] **Step 1: Add `stickySwipe` to AnimationTokens**

Open `WeeklyPlanner/DesignSystem/AnimationTokens.swift` and add after the `stickyPeel` definition:

```swift
static let stickySwipe = Animation.spring(duration: 0.3, bounce: 0.15)
```

- [ ] **Step 2: Add reduce-motion variant**

Open `WeeklyPlanner/Accessibility/ReduceMotionAnimations.swift` and add after the `stickyPeel(reduced:)` factory:

```swift
static func stickySwipe(reduced: Bool) -> Animation {
    reduced ? .easeOut(duration: 0.18) : Self.stickySwipe
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild build -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/DesignSystem/AnimationTokens.swift WeeklyPlanner/Accessibility/ReduceMotionAnimations.swift
git commit -m "feat(sticky): add stickySwipe animation token with reduce-motion variant"
```

---

### Task 2: Rewrite `AIStickyStack` with swipe gesture and page dots

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/AIStickyStack.swift`

This is the core change. The `AIStickyStack` gains:
- `@State private var currentIndex: Int = 0` to track which insight is "on top"
- `@GestureState private var dragOffset: CGFloat = 0` for tracking in-progress swipe
- A horizontal `DragGesture` that commits when `|dx| > 30` and `|dx| > |dy|`
- Slide-out / slide-in animation using the `stickySwipe` token
- Page indicator dots below the stack when `insights.count > 1`
- `onShowAnother` callback replaced with `onNavigate: (Int) -> Void`

- [ ] **Step 1: Write failing tests for swipe navigation**

Open `WeeklyPlannerTests/DayPage/AIStickyStackTests.swift` and add these tests. They will fail because `AIStickyStack` doesn't have `currentIndex` or `onNavigate` yet:

```swift
func testCurrentIndex_defaultsToZero() {
    let stack = AIStickyStack(
        insights: [insight(.travel, "T"), insight(.weather, "W")],
        onTap: { _ in }, onDismiss: { _ in },
        onRefresh: {}, onNavigate: { _ in })
    XCTAssertEqual(stack.currentIndex, 0)
}

func testNavigateForward_callsOnNavigateWithNextIndex() async {
    let exp = expectation(description: "onNavigate fires")
    var navigatedTo: Int?
    let stack = AIStickyStack(
        insights: [insight(.travel, "T"), insight(.weather, "W"), insight(.keyword, "K")],
        onTap: { _ in }, onDismiss: { _ in },
        onRefresh: {}, onNavigate: { idx in navigatedTo = idx; exp.fulfill() })
    stack.onNavigate(1)
    await fulfillment(of: [exp], timeout: 0.5)
    XCTAssertEqual(navigatedTo, 1)
}

func testNavigateBackward_callsOnNavigateWithPrevIndex() async {
    let exp = expectation(description: "onNavigate fires")
    var navigatedTo: Int?
    let stack = AIStickyStack(
        insights: [insight(.travel, "T"), insight(.weather, "W"), insight(.keyword, "K")],
        onTap: { _ in }, onDismiss: { _ in },
        onRefresh: {}, onNavigate: { idx in navigatedTo = idx; exp.fulfill() })
    stack.onNavigate(2)
    await fulfillment(of: [exp], timeout: 0.5)
    XCTAssertEqual(navigatedTo, 2)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:'WeeklyPlannerTests/AIStickyStackTests' -quiet 2>&1 | tail -10`
Expected: Compile errors — `onShowAnother` vs `onNavigate` mismatch.

- [ ] **Step 3: Rewrite `AIStickyStack.swift`**

Replace the full contents of `WeeklyPlanner/Features/DayPage/AIStickyStack.swift` with:

```swift
import SwiftUI

struct AIStickyStack: View {
    let insights: [AIInsight]
    let onTap: (AIInsight) -> Void
    let onDismiss: (AIInsight) -> Void
    let onRefresh: () -> Void
    let onNavigate: (Int) -> Void

    @State var currentIndex: Int = 0
    @GestureState private var dragOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var safeIndex: Int {
        guard !insights.isEmpty else { return 0 }
        return min(currentIndex, insights.count - 1)
    }

    private var currentInsight: AIInsight? {
        guard !insights.isEmpty else { return nil }
        return insights[safeIndex]
    }

    var body: some View {
        if insights.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    // Behind stickies (peek layers)
                    ForEach(Array(insights.enumerated()), id: \.element.id) { idx, insight in
                        if idx != safeIndex, peekPosition(of: idx) <= 2, peekPosition(of: idx) > 0 {
                            AIStickyNote(insight: peekInsight(for: insight, at: peekPosition(of: idx)))
                                .allowsHitTesting(false)
                                .offset(peekOffset(at: peekPosition(of: idx)))
                                .opacity(0.92)
                                .zIndex(Double(2 - peekPosition(of: idx)))
                        }
                    }
                    // Top sticky with swipe gesture
                    if let top = currentInsight {
                        AIStickyNote(
                            insight: top,
                            onTap: { onTap(top) },
                            onLongPress: { },
                            onRefresh: onRefresh
                        )
                        .zIndex(10)
                        .offset(x: dragOffset)
                        .opacity(dragOpacity)
                        .highPriorityGesture(swipeGesture)
                        .contextMenu {
                            if insights.count > 1 {
                                Button {
                                    navigateForward()
                                } label: {
                                    Label("Show another", systemImage: "arrow.triangle.2.circlepath")
                                }
                            }
                            Button(role: .destructive) {
                                onDismiss(top)
                            } label: {
                                Label("Dismiss this insight", systemImage: "xmark.circle")
                            }
                            Button {
                                onRefresh()
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            if let actionLabel = actionLabel(for: top.kind) {
                                Button {
                                    onTap(top)
                                } label: {
                                    Label(actionLabel, systemImage: actionIcon(for: top.kind))
                                }
                            }
                        }
                        .accessibilityIdentifier("daypage.sticky.top")
                    }
                }
                .animation(AnimationTokens.stickySwipe(reduced: reduceMotion), value: currentIndex)

                // Page indicator dots
                if insights.count > 1 {
                    pageIndicator
                }
            }
            .onChange(of: insights.count) { _, newCount in
                if currentIndex >= newCount {
                    currentIndex = max(0, newCount - 1)
                }
            }
        }
    }

    // MARK: - Swipe gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($dragOffset) { value, state, _ in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy) {
                    state = dx
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy), abs(dx) > 30 else { return }
                if dx < 0 {
                    navigateForward()
                } else {
                    navigateBackward()
                }
            }
    }

    private var dragOpacity: Double {
        let progress = min(abs(dragOffset) / 120.0, 1.0)
        return 1.0 - (progress * 0.5)
    }

    private func navigateForward() {
        guard insights.count > 1 else { return }
        let next = (safeIndex + 1) % insights.count
        currentIndex = next
        onNavigate(next)
    }

    private func navigateBackward() {
        guard insights.count > 1 else { return }
        let prev = (safeIndex - 1 + insights.count) % insights.count
        currentIndex = prev
        onNavigate(prev)
    }

    // MARK: - Page indicator

    private var pageIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<insights.count, id: \.self) { idx in
                Circle()
                    .fill(idx == safeIndex ? Color.black.opacity(0.4) : Color.clear)
                    .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 0.5))
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityLabel("Page \(safeIndex + 1) of \(insights.count)")
        .accessibilityIdentifier("daypage.sticky.pageIndicator")
    }

    // MARK: - Peek helpers

    private func peekPosition(of idx: Int) -> Int {
        let offset = idx - safeIndex
        if offset > 0 { return offset }
        if offset < 0 { return insights.count + offset }
        return 0
    }

    private func peekInsight(for top: AIInsight, at position: Int) -> AIInsight {
        AIInsight(
            dayKey: top.dayKey,
            dateGenerated: top.dateGenerated,
            text: top.text,
            colorHex: top.colorHex,
            tiltDegrees: top.tiltDegrees - Double(2 * position),
            kind: top.kind,
            priority: top.priority
        )
    }

    private func peekOffset(at position: Int) -> CGSize {
        switch position {
        case 1: return CGSize(width: -4, height: 8)
        case 2: return CGSize(width: -8, height: 14)
        default: return .zero
        }
    }

    private func actionLabel(for kind: InsightKind) -> String? {
        switch kind {
        case .travel: return "Get directions"
        case .weather: return "Open Weather"
        case .keyword: return "Open event"
        case .inbox: return "Open inbox"
        case .encouragement: return nil
        }
    }

    private func actionIcon(for kind: InsightKind) -> String {
        switch kind {
        case .travel: return "map"
        case .weather: return "cloud.rain"
        case .keyword: return "calendar"
        case .inbox: return "tray"
        case .encouragement: return "sparkles"
        }
    }
}
```

Key design decisions:
- `currentIndex` is `@State` — resets on remount (page flip). No persistence needed.
- `peekPosition(of:)` computes relative offset from `currentIndex` for the circular peek layout.
- `dragOffset` is `@GestureState` so it auto-resets to 0 when the drag ends.
- `.highPriorityGesture` ensures the sticky claims horizontal swipes before the parent (though `PageFlipContainer` uses a different mechanism — buttons, not `DragGesture`).
- Dots use filled vs stroked circles at 5pt with 0.3 opacity — unobtrusive on paper.

- [ ] **Step 4: Update existing tests and add new ones**

Replace the full contents of `WeeklyPlannerTests/DayPage/AIStickyStackTests.swift` with:

```swift
import Foundation
import SwiftUI
import XCTest
@testable import WeeklyPlanner

@MainActor
final class AIStickyStackTests: XCTestCase {
    private func insight(_ kind: InsightKind, _ text: String) -> AIInsight {
        AIInsight(dayKey: "0:5", text: text,
                  colorHex: kind.colorHex, tiltDegrees: 0,
                  kind: kind, priority: kind.defaultPriority)
    }

    // MARK: - Existing tests (updated API)

    func testZeroInsightsRendersEmpty() {
        let stack = AIStickyStack(insights: [],
                                   onTap: { _ in }, onDismiss: { _ in },
                                   onRefresh: {}, onNavigate: { _ in })
        XCTAssertNotNil(stack)
    }

    func testThreeInsightsCapsAtThree() {
        let stack = AIStickyStack(
            insights: [insight(.travel, "T"), insight(.weather, "W"),
                       insight(.keyword, "K"), insight(.inbox, "I")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: {}, onNavigate: { _ in })
        XCTAssertEqual(stack.insights.count, 4,
                       "Input array passes through; view caps via ForEach idx check")
    }

    func testTapCallback_invokedWithTopInsight() async {
        let exp = expectation(description: "onTap fires")
        var tapped: AIInsight?
        let top = insight(.travel, "T")
        let stack = AIStickyStack(
            insights: [top, insight(.weather, "W")],
            onTap: { tapped = $0; exp.fulfill() },
            onDismiss: { _ in }, onRefresh: {}, onNavigate: { _ in })
        stack.onTap(top)
        await fulfillment(of: [exp], timeout: 0.5)
        XCTAssertEqual(tapped?.kind, .travel)
    }

    func testDismissCallback_invokedWithTopInsight() async {
        let exp = expectation(description: "onDismiss fires")
        var dismissed: AIInsight?
        let top = insight(.weather, "W")
        let stack = AIStickyStack(
            insights: [top],
            onTap: { _ in },
            onDismiss: { dismissed = $0; exp.fulfill() },
            onRefresh: {}, onNavigate: { _ in })
        stack.onDismiss(top)
        await fulfillment(of: [exp], timeout: 0.5)
        XCTAssertEqual(dismissed?.kind, .weather)
    }

    func testRefreshCallback_invokedDirectly() async {
        let exp = expectation(description: "onRefresh fires")
        let stack = AIStickyStack(
            insights: [insight(.travel, "T")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: { exp.fulfill() }, onNavigate: { _ in })
        stack.onRefresh()
        await fulfillment(of: [exp], timeout: 0.5)
    }

    // MARK: - New: currentIndex

    func testCurrentIndex_defaultsToZero() {
        let stack = AIStickyStack(
            insights: [insight(.travel, "T"), insight(.weather, "W")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: {}, onNavigate: { _ in })
        XCTAssertEqual(stack.currentIndex, 0)
    }

    // MARK: - New: onNavigate callback

    func testNavigateCallback_invokedWithIndex() async {
        let exp = expectation(description: "onNavigate fires")
        var navigatedTo: Int?
        let stack = AIStickyStack(
            insights: [insight(.travel, "T"), insight(.weather, "W"), insight(.keyword, "K")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: {}, onNavigate: { idx in navigatedTo = idx; exp.fulfill() })
        stack.onNavigate(1)
        await fulfillment(of: [exp], timeout: 0.5)
        XCTAssertEqual(navigatedTo, 1)
    }

    // MARK: - New: page indicator

    func testPageIndicator_multipleInsights_dotCountMatchesInsightsCount() {
        let stack = AIStickyStack(
            insights: [insight(.travel, "T"), insight(.weather, "W"), insight(.keyword, "K")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: {}, onNavigate: { _ in })
        XCTAssertEqual(stack.insights.count, 3,
                       "Page indicator should show 3 dots for 3 insights")
    }

    func testPageIndicator_singleInsight_noDotsShown() {
        let stack = AIStickyStack(
            insights: [insight(.travel, "T")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: {}, onNavigate: { _ in })
        XCTAssertEqual(stack.insights.count, 1,
                       "Page indicator should not render for a single insight")
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:'WeeklyPlannerTests/AIStickyStackTests' -quiet 2>&1 | tail -10`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/AIStickyStack.swift WeeklyPlannerTests/DayPage/AIStickyStackTests.swift
git commit -m "feat(sticky): swipe-to-navigate with page indicator dots on AIStickyStack"
```

---

### Task 3: Update `DayPageView` to use index-based navigation

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift:322-347`

The `stickyNoteOverlay` currently passes `onShowAnother: { promoteNextSticky() }`. We need to:
1. Replace `onShowAnother` with `onNavigate` (no-op — the stack manages its own `currentIndex` now).
2. Remove `promoteNextSticky()` since the array rotation is no longer needed.

- [ ] **Step 1: Update `stickyNoteOverlay`**

In `DayPageView.swift`, find the `stickyNoteOverlay` computed property (around line 322) and replace:

```swift
@ViewBuilder
private var stickyNoteOverlay: some View {
    if let insights = viewModel?.insights, !insights.isEmpty {
        AIStickyStack(
            insights: insights,
            onTap: { insight in handleStickyTap(insight) },
            onDismiss: { insight in
                Task { await viewModel?.dismissInsight(insight) }
            },
            onRefresh: {
                Task { await viewModel?.refreshInsights() }
            },
            onShowAnother: { promoteNextSticky() })
            .padding(.top, 96)
            .padding(.trailing, 16)
    }
}
```

with:

```swift
@ViewBuilder
private var stickyNoteOverlay: some View {
    if let insights = viewModel?.insights, !insights.isEmpty {
        AIStickyStack(
            insights: insights,
            onTap: { insight in handleStickyTap(insight) },
            onDismiss: { insight in
                Task { await viewModel?.dismissInsight(insight) }
            },
            onRefresh: {
                Task { await viewModel?.refreshInsights() }
            },
            onNavigate: { _ in })
            .padding(.top, 96)
            .padding(.trailing, 16)
    }
}
```

- [ ] **Step 2: Remove `promoteNextSticky()`**

Delete the `promoteNextSticky()` method (around lines 339-347):

```swift
/// Phase 24 — when the user explicitly taps "Show another" in the
/// cascade context menu, we rotate the insights array so the second
/// becomes the top. SwiftData order doesn't change; this is purely a
/// view-state pop-and-push.
private func promoteNextSticky() {
    guard let vm = viewModel, vm.insights.count > 1 else { return }
    let first = vm.insights.removeFirst()
    vm.insights.append(first)
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild build -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run full test suite**

Run: `xcodebuild test -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:'WeeklyPlannerTests' -quiet 2>&1 | tail -15`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageView.swift
git commit -m "refactor(sticky): replace array-rotation promote with index-based onNavigate"
```

---

### Task 4: Final review — build, test, verify

- [ ] **Step 1: Full build**

Run: `xcodebuild build -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Full unit test suite**

Run: `xcodebuild test -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:'WeeklyPlannerTests' -quiet 2>&1 | tail -15`
Expected: All tests pass, zero failures.

- [ ] **Step 3: Verify no regressions in UI tests**

Run: `xcodebuild test -scheme WeeklyPlanner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:'WeeklyPlannerUITests/AIStickyStackUITests' -quiet 2>&1 | tail -10`
Expected: All UI tests pass.

- [ ] **Step 4: Verify against spec checklist**

Cross-check against `docs/phases/phase-24-ai-sticky-v2.md` swipe-to-navigate section:
- [x] Horizontal `DragGesture` on top sticky — left advances, right goes back
- [x] Gesture scoped to sticky's hit area (`.highPriorityGesture`)
- [x] 30pt minimum threshold, `abs(dx) > abs(dy)` guard
- [x] Slide + opacity animation, ~0.3s spring
- [x] Reduce-motion: 0.18s easeOut (no slide — `@GestureState` auto-resets)
- [x] Wraps around in both directions
- [x] Page indicator dots: 5pt circles, filled/stroked, 4pt spacing
- [x] Context menu "Show another" preserved as secondary path
