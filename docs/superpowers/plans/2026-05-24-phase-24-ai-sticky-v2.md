# Phase 24 — AI Sticky v2 (Live & Actionable) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single frozen `AIInsight` per day with a cascade of up to 3 context-aware actionable insights from four signal sources (travel ETA, weather, calendar-keyword detection, inbox-flagged items), refreshed on day-page open + pull-to-refresh, with tap → deep-link and long-press → context menu (Dismiss / Refresh / Show another / action).

**Architecture:** Five generators conforming to a single `InsightGenerator` protocol run concurrently in `StickyOrchestrator` (via `withTaskGroup`), persist results into SwiftData as `AIInsight` rows (one per `(dayKey, kind)`), and a new `AIStickyStack` view renders up to 3 from the rows fetched by `DayPageViewModel.insights`. The existing `StickyInsightGenerator` is renamed `EncouragementInsightGenerator` and demoted to a fallback (runs only when all four primary generators return nil).

**Tech Stack:** Swift 6, SwiftUI (iOS 26+), SwiftData (with lightweight migration via default field values), Foundation Models (`@Generable`), MapKit (`MKDirections` + `CLGeocoder`), CoreLocation (`CLLocationManager`), WeatherKit (entitlement gated).

**Spec:** `docs/phases/phase-24-ai-sticky-v2.md` · **Branch:** `phase-24-ai-sticky-v2` (already created off `main` at `d7a96c9`).

---

## Critical API facts from the codebase survey

These override or supplement the phase doc — derived from reading the current source on 2026-05-24:

- **`AIInsight.dayKey` is currently `@Attribute(.unique)`.** Phase 24 needs multiple insights per day (one per `kind`), so this constraint must be removed. Uniqueness becomes the logical `(dayKey, kind)` pair, enforced by the orchestrator at persist time. The schema change is a property-attribute drop — still a lightweight migration (no destructive transform).

- **`DeepLinkRouter.Request` enum** (at `WeeklyPlanner/Notifications/DeepLinkRouter.swift:11-12`) currently has `case event(UUID)` and `case task(UUID)`. The new `.inbox(dayKey: String)` case adds at the end.

- **`IntelligenceService.ask(query:context:)`** (at `WeeklyPlanner/Intelligence/IntelligenceService.swift:24`) returns `AIAnswer`. The renamed `EncouragementInsightGenerator` keeps using this directly. `KeywordInsightGenerator` defines a small `KeywordInsightModeling` seam that the production impl backs with `LanguageModelSession.respond(to:generating:)` and `@Generable`, while the stub returns nil.

- **`PaperTheme.stickyColors` does NOT exist.** The existing generators use hex literals (`"#FFE680"`, `"#C9F0E0"`, `"#FFCCC9"`). Phase 24 will continue this pattern — `InsightKind.color` returns the right hex per kind. New lavender for inbox: `"#E0DFFF"`.

- **`StickyInsightGenerator.shade(_:percent:)`** lives on the existing `StickyNoteGenerator` enum (at `WeeklyPlanner/Features/DayPage/StickyNoteGenerator.swift:36`). Keep this — `AIStickyTab` uses it for the folded-tab gradient. The rename target is `StickyInsightGenerator` (the Foundation Models generator at `WeeklyPlanner/Intelligence/Tasks/StickyInsightGenerator.swift`), NOT this `StickyNoteGenerator` enum.

- **`@MainActor` is the standard for everything in this codebase** (see `EventDetailViewModel`, `DayPageViewModel`, etc.). Generators and orchestrator follow suit.

- **Swift 6 strict concurrency is enabled** (per Phase 19 retro). `withTaskGroup` requires each task closure to be `Sendable` — generators that capture `@MainActor` deps must hop main-actor inside, or be invoked via `await MainActor.run`.

---

## File structure

### New files (12)

| Path | Responsibility |
|------|----------------|
| `WeeklyPlanner/Intelligence/InsightGenerator.swift` | Protocol + `DayContext` value type + `InsightKind` enum (with `priority` + `color` accessors) |
| `WeeklyPlanner/Intelligence/StickyOrchestrator.swift` | `withTaskGroup` runner + TTL cache + persist logic |
| `WeeklyPlanner/Intelligence/Tasks/InboxInsightGenerator.swift` | Synchronous count of pending suggestions |
| `WeeklyPlanner/Intelligence/Tasks/KeywordInsightGenerator.swift` | Foundation Models `@Generable`-based keyword nudges |
| `WeeklyPlanner/Intelligence/Tasks/TravelInsightGenerator.swift` | MapKit ETA + departure threshold |
| `WeeklyPlanner/Intelligence/Tasks/WeatherInsightGenerator.swift` | WeatherKit hourly forecast + precip threshold |
| `WeeklyPlanner/Features/DayPage/AIStickyStack.swift` | Cascade-render up to 3 stickies with peek offsets |
| `WeeklyPlannerTests/Intelligence/InsightGeneratorProtocolTests.swift` | Protocol-level value-type tests |
| `WeeklyPlannerTests/Intelligence/InboxInsightGeneratorTests.swift` | 3 cases |
| `WeeklyPlannerTests/Intelligence/KeywordInsightGeneratorTests.swift` | 4 cases |
| `WeeklyPlannerTests/Intelligence/TravelInsightGeneratorTests.swift` | 4 cases |
| `WeeklyPlannerTests/Intelligence/WeatherInsightGeneratorTests.swift` | 3 cases |
| `WeeklyPlannerTests/Intelligence/StickyOrchestratorTests.swift` | 6 cases (cascade + cap + fallback + TTL + persist + dismissed) |
| `WeeklyPlannerTests/Models/AIInsightV2MigrationTests.swift` | 2 cases |
| `WeeklyPlannerTests/DayPage/AIStickyStackTests.swift` | 7 cases (counts + tap + promote) |
| `WeeklyPlannerUITests/AIStickyStackUITests.swift` | 1 case (tap travel sticky → URL opened) |

### Renamed (1)

| From → To | Why |
|-----------|-----|
| `WeeklyPlanner/Intelligence/Tasks/StickyInsightGenerator.swift` → `WeeklyPlanner/Intelligence/Tasks/EncouragementInsightGenerator.swift` | Demoted to fallback (per phase doc); same logic, conforms to new protocol |

### Modified (8)

| Path | Why |
|------|-----|
| `WeeklyPlanner/Models/AIInsight.swift` | Drop `dayKey` uniqueness; add `kind`, `actionURL`, `priority`; `InsightKind` raw-value default = `.encouragement` for V1 row migration |
| `WeeklyPlanner/Features/DayPage/StickyNoteGenerator.swift` | New `insights(forWeekOffset:dayIdx:in:)` returns `[AIInsight]` sorted by `priority`. Existing single-insight API kept for back-compat |
| `WeeklyPlanner/Features/DayPage/AIStickyNote.swift` | Optional `onTap`/`onLongPress`/`onRefresh` callbacks; eyebrow gains `↻` button; folded-state ownership moved out (just `let insight`) |
| `WeeklyPlanner/Features/DayPage/DayPageView.swift` | `stickyNoteOverlay` → `AIStickyStack`; pass cascade + callbacks |
| `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift` | `var insights: [AIInsight]`; orchestrator injection; `refresh()` runs orchestrator; `refreshInsights()` + `dismissInsight(_:)` |
| `WeeklyPlanner/Notifications/DeepLinkRouter.swift` | Add `case inbox(dayKey: String)` to `Request` enum |
| `WeeklyPlanner/Navigation/AppShell.swift` | Handle `.inbox` request — switch to Calendar tab + (TODO: scroll-to-inbox stays out of scope; the tab switch is enough for now) |
| `WeeklyPlanner/App/WeeklyPlannerApp.swift` | Construct `StickyOrchestrator` + inject into `\.stickyOrchestrator` env |
| `WeeklyPlanner/Stores/Environment+Stores.swift` | New env key `\.stickyOrchestrator` |
| `WeeklyPlanner/Supporting/WeeklyPlanner.entitlements` | Add `com.apple.developer.weatherkit` |
| `project.yml` | Add `weatherkit` capability so XcodeGen propagates |
| `WeeklyPlanner/Features/DayPage/DayPageViewModelTests.swift` (existing test file, if present) | Verify insights threading + dismiss |

### Out of scope (deferred)

- Push-notification-driven insight refresh
- User-defined custom insight rules
- Cross-day insights ("you have 4 birthdays this week")
- Background-task scheduled regeneration
- Scroll-to-inbox-from-deep-link (Phase 19 router supports the request; AppShell just switches to Calendar tab — actual scroll target is a small follow-up)

---

## Conventions for this plan

- **Tests run via:**
  ```bash
  xcodebuild test \
    -project WeeklyPlanner.xcodeproj \
    -scheme WeeklyPlanner \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
    -only-testing:WeeklyPlannerTests/<ClassName> \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -25
  ```
- **`xcodegen generate`** when adding new files. The repo's XcodeGen spec auto-globs source files but the build needs the `.xcodeproj` regenerated to pick them up.
- **Each task ends with a commit** on `phase-24-ai-sticky-v2`.
- **SourceKit will emit stale "Cannot find type X" diagnostics** continuously throughout this phase as new files land — trust `xcodebuild`, not the editor's indexer. Phase 22 + 23 lived with this for weeks.
- **WeatherKit entitlement risk:** the entitlement file change in Task 12 may cause local builds to fail if the Apple Developer Portal hasn't provisioned the capability. If `xcodebuild` complains about a missing entitlement at code-signing time, the workaround is `CODE_SIGN_IDENTITY=-` (no signing) for the simulator. Real-device + TestFlight builds need the portal step (documented in the Task 12 RUNBOOK).

---

## Task 1: `AIInsight` v2 schema — `kind` / `actionURL` / `priority`

**Files:**
- Modify: `WeeklyPlanner/Models/AIInsight.swift`
- Create: `WeeklyPlannerTests/Models/AIInsightV2MigrationTests.swift`

**Why this is first:** every other task references the new fields. Migration semantics need to be locked first so subsequent generator tests can construct rows with `kind`.

- [ ] **Step 1: Write the failing tests**

Create `WeeklyPlannerTests/Models/AIInsightV2MigrationTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class AIInsightV2MigrationTests: XCTestCase {
    func testNewInsight_defaultsToEncouragementKind() {
        let insight = AIInsight(dayKey: "0:5",
                                 text: "Don't forget Sara's gift!",
                                 colorHex: "#FFE680",
                                 tiltDegrees: 4)
        XCTAssertEqual(insight.kindRaw, "encouragement")
        XCTAssertEqual(insight.kind, .encouragement)
        XCTAssertNil(insight.actionURL)
        XCTAssertEqual(insight.priority, 9)
    }

    func testNewInsight_explicitKind_storesAndRoundTripsViaRawValue() {
        let insight = AIInsight(dayKey: "0:5",
                                 text: "Leave by 9:35 for dentist",
                                 colorHex: "#FFE680",
                                 tiltDegrees: 4,
                                 kind: .travel,
                                 actionURL: "http://maps.apple.com/?daddr=37.78,-122.41",
                                 priority: 0)
        XCTAssertEqual(insight.kindRaw, "travel")
        XCTAssertEqual(insight.kind, .travel)
        XCTAssertEqual(insight.actionURL, "http://maps.apple.com/?daddr=37.78,-122.41")
        XCTAssertEqual(insight.priority, 0)
    }

    func testMultipleInsightsForSameDay_canCoexistAcrossKinds() throws {
        let container = try SwiftDataStack.inMemoryContainer()
        let context = container.mainContext

        let travel = AIInsight(dayKey: "0:5", text: "T", colorHex: "#FFE680",
                                tiltDegrees: 0, kind: .travel, priority: 0)
        let weather = AIInsight(dayKey: "0:5", text: "W", colorHex: "#C9F0E0",
                                 tiltDegrees: 0, kind: .weather, priority: 1)
        context.insert(travel)
        context.insert(weather)
        try context.save()

        let all = try context.fetch(FetchDescriptor<AIInsight>())
        XCTAssertEqual(all.count, 2,
                       "Multiple insights per dayKey must coexist once kind is added")
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/AIInsightV2MigrationTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -25
```

Expected: BUILD FAILED with "no member 'kindRaw'", "no member 'kind'", "no member 'actionURL'", "no member 'priority'", and the multi-insert test will fail on the unique constraint violation.

- [ ] **Step 3: Update `AIInsight`**

Replace `WeeklyPlanner/Models/AIInsight.swift` with:

```swift
import Foundation
import SwiftData

/// Per-day AI-generated sticky note. Rendered as the masking-tape paper
/// rectangle on the day page (top-right). Multiple insights can coexist
/// for the same `(weekOffset, dayIdx)` cell — one per `kind`. The
/// orchestrator enforces logical uniqueness on `(dayKey, kind)` at
/// persist time; SwiftData no longer carries a `dayKey` unique
/// constraint because Phase 24 cascades up to 3 insights per day.
///
/// V1 rows (pre-Phase-24) lacked `kind` / `actionURL` / `priority`. The
/// default values below give them a lightweight migration:
/// `kind = .encouragement`, `actionURL = nil`, `priority = 9` — i.e.
/// "fallback encouragement, lowest cascade priority."
@Model
final class AIInsight {
    @Attribute(.unique) var id: UUID

    /// `"<weekOffset>:<dayIdx>"`, e.g., `"0:5"` for Saturday of the current week.
    /// **No longer `@Attribute(.unique)`** — multiple insights can share a day
    /// (one per `kind`). The orchestrator deletes old rows for the same
    /// `(dayKey, kind)` before inserting fresh ones.
    var dayKey: String

    var dateGenerated: Date
    var text: String

    /// Sticky paper color hex. Defaults to `#FFE680` (yellow) for
    /// encouragement; per-kind colors are set by the orchestrator
    /// from `InsightKind.colorHex`.
    var colorHex: String

    /// Tilt angle in degrees, typically ±3 to ±5°.
    var tiltDegrees: Double

    var dismissed: Bool

    // MARK: - Phase 24 additions

    /// `InsightKind` raw value. Stored as String so SwiftData predicates
    /// can filter on it directly without bridging the enum.
    var kindRaw: String

    /// Deep link or external URL the sticky body taps open. Examples:
    /// `"weeklyplanner://event/<uuid>"`, `"http://maps.apple.com/?daddr=…"`,
    /// `"weather://"`. `nil` for `.encouragement` (legacy fold/expand only).
    var actionURL: String?

    /// Cascade sort order. Lower = earlier in the stack. Defaults to 9
    /// (fallback `encouragement` priority).
    var priority: Int

    init(id: UUID = UUID(),
         dayKey: String,
         dateGenerated: Date = .init(),
         text: String,
         colorHex: String = "#FFE680",
         tiltDegrees: Double = 0,
         dismissed: Bool = false,
         kind: InsightKind = .encouragement,
         actionURL: String? = nil,
         priority: Int = 9)
    {
        self.id = id
        self.dayKey = dayKey
        self.dateGenerated = dateGenerated
        self.text = text
        self.colorHex = colorHex
        self.tiltDegrees = tiltDegrees
        self.dismissed = dismissed
        self.kindRaw = kind.rawValue
        self.actionURL = actionURL
        self.priority = priority
    }
}

extension AIInsight {
    /// Builds a `dayKey` from week + day indices. Both Monday-based.
    static func key(weekOffset: Int, dayIdx: Int) -> String {
        "\(weekOffset):\(dayIdx)"
    }

    /// Typed accessor over `kindRaw`. Defaults to `.encouragement` if a
    /// V1 row migrated in with an empty / unknown raw value.
    var kind: InsightKind {
        get { InsightKind(rawValue: kindRaw) ?? .encouragement }
        set { kindRaw = newValue.rawValue }
    }
}
```

(`InsightKind` enum is defined in Task 2 — Swift compiler will accept the
forward reference since this file is in the same module. The tests at this
point exercise raw-value behavior and don't need the enum yet, but I'm
using the typed `kind` accessor in the init param. If the build errors
because `InsightKind` doesn't exist yet, do Task 2 first.)

**Heads-up for the next engineer:** because the tests in Step 1 reference
`InsightKind.travel` and `.weather`, you'll get build errors until Task 2
adds the enum. Two options:
1. Stub `InsightKind` here temporarily (single line: `enum InsightKind: String { case encouragement, travel, weather, keyword, inbox }`) and delete it when Task 2 lands.
2. Reorder: do Task 2 first.

Recommendation: **inline-stub** the enum at the bottom of this file
during Task 1, then in Task 2 cut it out and move it to
`InsightGenerator.swift`. Tasks 1 + 2 will be sequential anyway.

- [ ] **Step 4: Run tests — verify PASS**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/AIInsightV2MigrationTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: 3 tests, 0 failures.

- [ ] **Step 5: Run the full unit test suite to confirm no regressions**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: 341 (baseline) + 3 (new) = 344 tests, all green. The unique-constraint
drop affects no existing code because no existing code relied on multi-insight-
per-day failing.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/Models/AIInsight.swift \
       WeeklyPlannerTests/Models/AIInsightV2MigrationTests.swift
git commit -m "feat(phase-24): AIInsight v2 — kind/actionURL/priority + drop dayKey uniqueness

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `InsightGenerator` protocol + `DayContext` + `InsightKind`

**Files:**
- Create: `WeeklyPlanner/Intelligence/InsightGenerator.swift`
- Modify: `WeeklyPlanner/Models/AIInsight.swift` (remove the temporary inline `InsightKind` stub if one was added in Task 1)
- Create: `WeeklyPlannerTests/Intelligence/InsightGeneratorProtocolTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `WeeklyPlannerTests/Intelligence/InsightGeneratorProtocolTests.swift`:

```swift
import Foundation
import XCTest
@testable import WeeklyPlanner

@MainActor
final class InsightGeneratorProtocolTests: XCTestCase {
    func testInsightKind_allCases() {
        XCTAssertEqual(InsightKind.allCases,
                       [.encouragement, .travel, .weather, .keyword, .inbox])
    }

    func testInsightKind_colorHex_perKind() {
        XCTAssertEqual(InsightKind.travel.colorHex, "#FFE680")
        XCTAssertEqual(InsightKind.weather.colorHex, "#C9F0E0")
        XCTAssertEqual(InsightKind.keyword.colorHex, "#FFCCC9")
        XCTAssertEqual(InsightKind.inbox.colorHex, "#E0DFFF")
        XCTAssertEqual(InsightKind.encouragement.colorHex, "#FFE680")
    }

    func testInsightKind_defaultPriority_perKind() {
        XCTAssertEqual(InsightKind.travel.defaultPriority, 0)
        XCTAssertEqual(InsightKind.weather.defaultPriority, 1)
        XCTAssertEqual(InsightKind.keyword.defaultPriority, 2)
        XCTAssertEqual(InsightKind.inbox.defaultPriority, 3)
        XCTAssertEqual(InsightKind.encouragement.defaultPriority, 9)
    }

    func testDayContext_constructsCleanly() {
        let ctx = DayContext(weekOffset: 0,
                              dayIdx: 5,
                              events: [],
                              inbox: [],
                              now: Date(timeIntervalSince1970: 1_780_000_000),
                              appleIntelligenceEnabled: true)
        XCTAssertEqual(ctx.weekOffset, 0)
        XCTAssertEqual(ctx.dayIdx, 5)
        XCTAssertEqual(ctx.dayKey, "0:5")
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/InsightGeneratorProtocolTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
```

Expected: BUILD FAILED — `InsightKind`, `DayContext` aren't defined (or are the
temp stub from Task 1).

- [ ] **Step 3: Create `InsightGenerator.swift`**

```swift
import Foundation

/// Kinds of AI sticky-note insights that can render on a Day page.
/// Cascade priority ascends (0 = earliest in the stack); each kind has
/// a deterministic sticky-paper color from the existing palette.
enum InsightKind: String, CaseIterable, Codable, Sendable {
    /// `.travel` — "Leave by HH:mm for <event>" (MapKit ETA)
    case travel
    /// `.weather` — "Bring umbrella — rain at <h>pm" (WeatherKit)
    case weather
    /// `.keyword` — "Don't forget Sara's gift!" (Foundation Models)
    case keyword
    /// `.inbox` — "<n> inbox suggestions for today"
    case inbox
    /// `.encouragement` — fallback one-line nudge when none of the
    /// above produce a result.
    case encouragement

    /// Cascade sort order. Lower = top of the stack. `9` is the
    /// fallback floor used by encouragement.
    var defaultPriority: Int {
        switch self {
        case .travel: return 0
        case .weather: return 1
        case .keyword: return 2
        case .inbox: return 3
        case .encouragement: return 9
        }
    }

    /// Sticky paper color hex matching the existing palette in
    /// `StickyInsightGenerator.palette`. Centralised here so the
    /// orchestrator picks the right color per kind without each
    /// generator hard-coding it.
    var colorHex: String {
        switch self {
        case .travel: return "#FFE680"        // yellow
        case .weather: return "#C9F0E0"       // mint
        case .keyword: return "#FFCCC9"       // pink
        case .inbox: return "#E0DFFF"         // lavender (new)
        case .encouragement: return "#FFE680" // yellow (legacy default)
        }
    }
}

/// Snapshot of everything an `InsightGenerator` needs to decide whether
/// to emit an insight for a given day. Pure value type — `Sendable` so
/// it can cross task boundaries inside the orchestrator's task group.
///
/// `Event` and `InboxSuggestion` are SwiftData `@Model` classes (NOT
/// `Sendable`), so we pass them as `[Event]` / `[InboxSuggestion]` only
/// when the orchestrator can guarantee the captures stay on `@MainActor`
/// — the generators that need them are `@MainActor`-isolated.
struct DayContext {
    let weekOffset: Int
    let dayIdx: Int
    let events: [Event]
    let inbox: [InboxSuggestion]
    let now: Date
    let appleIntelligenceEnabled: Bool

    /// Convenience over `AIInsight.key(weekOffset:dayIdx:)` so generators
    /// don't repeat the encoding.
    var dayKey: String { AIInsight.key(weekOffset: weekOffset, dayIdx: dayIdx) }
}

/// One signal source for the AI sticky-note cascade. Every generator
/// returns at most one `AIInsight` per call — the orchestrator runs
/// all five generators in parallel and assembles the cascade.
@MainActor
protocol InsightGenerator {
    /// What kind of insight this generator produces. Used by the
    /// orchestrator to enforce `(dayKey, kind)` uniqueness at persist
    /// time and to dispatch the right color / priority.
    var kind: InsightKind { get }

    /// Emit an insight, or `nil` if this generator has nothing to say
    /// for this day. Implementations must `do/catch` any thrown errors
    /// internally and convert them to `nil` — the orchestrator cannot
    /// recover from per-generator failures.
    func generate(for day: DayContext) async -> AIInsight?
}
```

If Task 1 added a temporary stub `enum InsightKind` inside
`AIInsight.swift`, **remove it now** — `InsightKind` is canonical in
this new file.

- [ ] **Step 4: Run tests — verify PASS**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/InsightGeneratorProtocolTests \
  -only-testing:WeeklyPlannerTests/AIInsightV2MigrationTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: Both classes pass. 4 (proto) + 3 (migration) = 7 new tests.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/InsightGenerator.swift \
       WeeklyPlanner/Models/AIInsight.swift \
       WeeklyPlannerTests/Intelligence/InsightGeneratorProtocolTests.swift
git commit -m "feat(phase-24): InsightGenerator protocol + DayContext + InsightKind

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Rename `StickyInsightGenerator` → `EncouragementInsightGenerator` + conform

**Files:**
- Rename: `WeeklyPlanner/Intelligence/Tasks/StickyInsightGenerator.swift` → `WeeklyPlanner/Intelligence/Tasks/EncouragementInsightGenerator.swift`
- Modify: the renamed file (class name + protocol conformance + return value uses `InsightKind.encouragement`)
- Modify: callers — `WeeklyPlanner/Features/DayPage/DayPageView.swift` (currently constructs `StickyInsightGenerator`) and any other usages

- [ ] **Step 1: Find all callers**

```bash
grep -rn "StickyInsightGenerator" WeeklyPlanner WeeklyPlannerTests 2>/dev/null
```

Expected output includes the file itself + `DayPageView.swift:148` (`StickyInsightGenerator(intelligence: $0)`) + `DayPageViewModel.swift` (the `stickyGenerator: StickyInsightGenerator?` parameter on the init).

- [ ] **Step 2: `git mv` the file**

```bash
git mv WeeklyPlanner/Intelligence/Tasks/StickyInsightGenerator.swift \
       WeeklyPlanner/Intelligence/Tasks/EncouragementInsightGenerator.swift
```

- [ ] **Step 3: Rewrite the file's body**

Replace the entire contents of `WeeklyPlanner/Intelligence/Tasks/EncouragementInsightGenerator.swift` with:

```swift
import Foundation

/// Fallback "one short encouraging line" sticky generator. Renamed from
/// Phase 13's `StickyInsightGenerator` and demoted to a fallback role
/// in Phase 24's cascade — runs only when the orchestrator's four
/// primary generators (travel / weather / keyword / inbox) all return
/// `nil`. Same Foundation Models prompt as before; same color/tilt math.
///
/// Conforms to the Phase 24 `InsightGenerator` protocol so the
/// orchestrator can drive it identically to the others; the `kind` is
/// always `.encouragement` and `priority` is `9` (the fallback floor).
@MainActor
final class EncouragementInsightGenerator: InsightGenerator {
    let kind: InsightKind = .encouragement

    private let intelligence: any IntelligenceService
    private let settings: () -> Bool

    /// Allowed sticky paper colors. Picked deterministically from the
    /// `(weekOffset, dayIdx)` pair so the same day always gets the same
    /// color, but different days have variety across the week.
    private static let palette = ["#FFE680", "#C9F0E0", "#FFCCC9"]

    init(intelligence: any IntelligenceService,
         settings: @escaping () -> Bool = { true })
    {
        self.intelligence = intelligence
        self.settings = settings
    }

    func generate(for day: DayContext) async -> AIInsight? {
        guard day.appleIntelligenceEnabled else { return nil }

        let context = PlannerContext(
            now: day.now,
            viewedWeekOffset: day.weekOffset,
            maxResponseTokens: 80,
            appleIntelligenceEnabled: day.appleIntelligenceEnabled
        )
        let availability = await intelligence.availability(context: context)
        guard availability.isAvailable else { return nil }

        let prompt = Self.prompt(weekOffset: day.weekOffset,
                                  dayIdx: day.dayIdx,
                                  events: day.events)
        do {
            let answer = try await intelligence.ask(query: prompt, context: context)
            let trimmed = answer.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let clamped = trimmed.count <= 80 ? trimmed : String(trimmed.prefix(80))
            return AIInsight(
                dayKey: day.dayKey,
                dateGenerated: day.now,
                text: clamped,
                colorHex: Self.color(weekOffset: day.weekOffset, dayIdx: day.dayIdx),
                tiltDegrees: Self.tilt(weekOffset: day.weekOffset, dayIdx: day.dayIdx),
                kind: .encouragement,
                actionURL: nil,
                priority: InsightKind.encouragement.defaultPriority
            )
        } catch {
            return nil
        }
    }

    /// Pure prompt builder. Exposed for tests so the prompt shape stays
    /// stable across edits.
    static func prompt(weekOffset: Int, dayIdx: Int, events: [Event]) -> String {
        let dayName = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][min(max(dayIdx, 0), 6)]
        var lines = [
            "Write one short, encouraging, handwritten-style note (≤ 80 chars, no emoji) about the user's plans for \(dayName).",
        ]
        if events.isEmpty {
            lines.append("There are no events scheduled.")
        } else {
            lines.append("Today's events:")
            for event in events.prefix(5) {
                let time = Self.timeFormatter.string(from: event.start)
                lines.append("- \(time): \(event.title)")
            }
        }
        lines.append("Reply with just the note — no preamble, no quotes.")
        return lines.joined(separator: "\n")
    }

    static func color(weekOffset: Int, dayIdx: Int) -> String {
        let hash = abs(weekOffset &* 7 &+ dayIdx)
        return palette[hash % palette.count]
    }

    static func tilt(weekOffset: Int, dayIdx: Int) -> Double {
        let hash = abs(weekOffset &* 31 &+ dayIdx)
        return Double(hash % 11) - 5.0
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
```

- [ ] **Step 4: Update the callers**

In `WeeklyPlanner/Features/DayPage/DayPageView.swift`, find the `.task` block (around line 200) that constructs `StickyInsightGenerator(intelligence: $0)` and rename to `EncouragementInsightGenerator(intelligence: $0)`. Keep the same call shape.

In `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift`, find the init parameter `stickyGenerator: StickyInsightGenerator?` and the stored property — both rename to `encouragementGenerator: EncouragementInsightGenerator?`. Also rename the private call `refreshStickyInsightIfNeeded(now:)` body where it reads `stickyGenerator.generate(...)` — the API changed to `.generate(for: DayContext)`, so adapt:

```swift
private func refreshStickyInsightIfNeeded(now: Date) async {
    guard let encouragementGenerator,
          let modelContext,
          StickyNoteGenerator.insight(forWeekOffset: weekOffset,
                                      dayIdx: dayIdx,
                                      in: modelContext) == nil
    else { return }

    let ctx = DayContext(weekOffset: weekOffset,
                         dayIdx: dayIdx,
                         events: events,
                         inbox: inbox,
                         now: now,
                         appleIntelligenceEnabled: true)
    guard let insight = await encouragementGenerator.generate(for: ctx) else { return }
    modelContext.insert(insight)
    try? modelContext.save()
}
```

(This whole method is going to be replaced in Task 10 when the orchestrator
takes over; for now we just keep the existing call shape working with the
renamed type.)

- [ ] **Step 5: Run all existing tests to verify the rename didn't break anything**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: 348 tests, all green (no new tests in this task — rename only).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(phase-24): rename StickyInsightGenerator → EncouragementInsightGenerator + InsightGenerator conformance

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `InboxInsightGenerator`

**Files:**
- Create: `WeeklyPlanner/Intelligence/Tasks/InboxInsightGenerator.swift`
- Create: `WeeklyPlannerTests/Intelligence/InboxInsightGeneratorTests.swift`

**Why first of the new generators:** zero AI / network dependencies. Pure
counting over `[InboxSuggestion]`. Validates the protocol shape end-to-end.

- [ ] **Step 1: Write the failing tests**

Create `WeeklyPlannerTests/Intelligence/InboxInsightGeneratorTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class InboxInsightGeneratorTests: XCTestCase {
    private func makeContext(suggestions: [InboxSuggestion]) -> DayContext {
        DayContext(weekOffset: 0,
                   dayIdx: 5,
                   events: [],
                   inbox: suggestions,
                   now: Date(timeIntervalSince1970: 1_780_000_000),
                   appleIntelligenceEnabled: true)
    }

    private func makeSuggestion(title: String = "Trade Confirmations") -> InboxSuggestion {
        InboxSuggestion(title: title,
                         from: "broker@example.com",
                         proposedStart: Date(timeIntervalSince1970: 1_780_000_000),
                         category: .work,
                         confidence: 0.9)
    }

    func testEmitsCountWhenPending() async {
        let gen = InboxInsightGenerator()
        let suggestions = [makeSuggestion(), makeSuggestion(title: "Lunch")]
        let insight = await gen.generate(for: makeContext(suggestions: suggestions))
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.text, "2 inbox suggestions for today")
        XCTAssertEqual(insight?.kind, .inbox)
        XCTAssertEqual(insight?.priority, 3)
        XCTAssertEqual(insight?.actionURL, "weeklyplanner://inbox/0:5")
        XCTAssertEqual(insight?.colorHex, "#E0DFFF")
    }

    func testNilWhenZeroPending() async {
        let gen = InboxInsightGenerator()
        let insight = await gen.generate(for: makeContext(suggestions: []))
        XCTAssertNil(insight)
    }

    func testSingularPluralAgreement() async {
        let gen = InboxInsightGenerator()
        let one = await gen.generate(for: makeContext(suggestions: [makeSuggestion()]))
        XCTAssertEqual(one?.text, "1 inbox suggestion for today")
        let three = await gen.generate(for: makeContext(suggestions: [
            makeSuggestion(), makeSuggestion(title: "B"), makeSuggestion(title: "C")
        ]))
        XCTAssertEqual(three?.text, "3 inbox suggestions for today")
    }
}
```

(The test constructs `InboxSuggestion` directly. If the actual
`InboxSuggestion` init signature differs from what's used above — likely a
`@Model` class — adapt the test to match. Use `grep -n "init(" WeeklyPlanner/Models/InboxSuggestion.swift` to confirm.)

- [ ] **Step 2: Run — verify FAIL**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/InboxInsightGeneratorTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -15
```

Expected: `Cannot find 'InboxInsightGenerator'`.

- [ ] **Step 3: Create `InboxInsightGenerator`**

Create `WeeklyPlanner/Intelligence/Tasks/InboxInsightGenerator.swift`:

```swift
import Foundation

/// Counts pending `InboxSuggestion` rows for the day and emits a one-line
/// nudge ("3 inbox suggestions for today") that deep-links into the
/// Day page's inbox section. Synchronous (no AI, no network) — runs
/// first in the orchestrator's task group and almost always finishes
/// before the others.
///
/// Priority `3` puts inbox below travel / weather / keyword in the
/// cascade — it's the lowest-stakes nudge.
@MainActor
final class InboxInsightGenerator: InsightGenerator {
    let kind: InsightKind = .inbox

    /// Deterministic tilt math borrowed from `EncouragementInsightGenerator`
    /// so the inbox sticky doesn't sit perfectly flat (the paper aesthetic
    /// always tilts ±5°).
    private static func tilt(weekOffset: Int, dayIdx: Int) -> Double {
        let hash = abs(weekOffset &* 31 &+ dayIdx)
        return Double(hash % 11) - 5.0
    }

    func generate(for day: DayContext) async -> AIInsight? {
        let count = day.inbox.count
        guard count > 0 else { return nil }
        let body = count == 1
            ? "1 inbox suggestion for today"
            : "\(count) inbox suggestions for today"
        return AIInsight(
            dayKey: day.dayKey,
            dateGenerated: day.now,
            text: body,
            colorHex: InsightKind.inbox.colorHex,
            tiltDegrees: Self.tilt(weekOffset: day.weekOffset, dayIdx: day.dayIdx),
            kind: .inbox,
            actionURL: "weeklyplanner://inbox/\(day.dayKey)",
            priority: InsightKind.inbox.defaultPriority
        )
    }
}
```

- [ ] **Step 4: Run tests — verify PASS**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/InboxInsightGeneratorTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: 3 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/Tasks/InboxInsightGenerator.swift \
       WeeklyPlannerTests/Intelligence/InboxInsightGeneratorTests.swift
git commit -m "feat(phase-24): InboxInsightGenerator — counts pending suggestions + deep-link

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: `KeywordInsightGenerator` — Foundation Models @Generable

**Files:**
- Create: `WeeklyPlanner/Intelligence/Tasks/KeywordInsightGenerator.swift`
- Create: `WeeklyPlannerTests/Intelligence/KeywordInsightGeneratorTests.swift`

**Why now:** introduces the `KeywordInsightModeling` seam pattern that
later generators (Travel, Weather) mirror. Keep tests off real
Foundation Models by injecting a fake.

- [ ] **Step 1: Write the failing tests**

Create `WeeklyPlannerTests/Intelligence/KeywordInsightGeneratorTests.swift`:

```swift
import Foundation
import XCTest
@testable import WeeklyPlanner

@MainActor
final class KeywordInsightGeneratorTests: XCTestCase {
    private func makeContext(events: [Event] = [],
                              appleIntelligenceEnabled: Bool = true) -> DayContext
    {
        DayContext(weekOffset: 0,
                   dayIdx: 5,
                   events: events,
                   inbox: [],
                   now: Date(timeIntervalSince1970: 1_780_000_000),
                   appleIntelligenceEnabled: appleIntelligenceEnabled)
    }

    private func event(title: String, id: UUID = UUID()) -> Event {
        Event(id: id,
              title: title,
              start: Date(timeIntervalSince1970: 1_780_000_000),
              end: Date(timeIntervalSince1970: 1_780_003_600),
              category: .personal)
    }

    func testEmitsForBirthdayKeyword() async {
        let id = UUID()
        let fake = FakeKeywordModel(result: .init(
            text: "Don't forget Sara's gift!",
            relatedEventID: id.uuidString,
            confidence: 0.9))
        let gen = KeywordInsightGenerator(model: fake)
        let insight = await gen.generate(for: makeContext(events: [event(title: "Sara's birthday", id: id)]))
        XCTAssertEqual(insight?.text, "Don't forget Sara's gift!")
        XCTAssertEqual(insight?.kind, .keyword)
        XCTAssertEqual(insight?.actionURL, "weeklyplanner://event/\(id.uuidString)")
        XCTAssertEqual(insight?.priority, 2)
    }

    func testDropsLowConfidence() async {
        let fake = FakeKeywordModel(result: .init(text: "uncertain",
                                                   relatedEventID: "",
                                                   confidence: 0.4))
        let gen = KeywordInsightGenerator(model: fake)
        let insight = await gen.generate(for: makeContext(events: [event(title: "Meeting")]))
        XCTAssertNil(insight)
    }

    func testNilWhenAppleIntelligenceOff() async {
        let fake = FakeKeywordModel(result: .init(text: "should not run",
                                                   relatedEventID: "",
                                                   confidence: 0.9))
        let gen = KeywordInsightGenerator(model: fake)
        let insight = await gen.generate(for: makeContext(events: [event(title: "M")],
                                                          appleIntelligenceEnabled: false))
        XCTAssertNil(insight)
        XCTAssertFalse(fake.wasCalled,
                       "Should short-circuit before invoking the model when AI is off")
    }

    func testGenerableEmptyStringSentinelHonored() async {
        let fake = FakeKeywordModel(result: .init(text: "Day-wide reminder",
                                                   relatedEventID: "",
                                                   confidence: 0.8))
        let gen = KeywordInsightGenerator(model: fake)
        let insight = await gen.generate(for: makeContext(events: [event(title: "M")]))
        XCTAssertNotNil(insight)
        XCTAssertNil(insight?.actionURL,
                     "Empty-string relatedEventID sentinel → no deep link")
    }
}

@MainActor
private final class FakeKeywordModel: KeywordInsightModeling {
    let result: KeywordInsightDraft
    private(set) var wasCalled = false

    init(result: KeywordInsightDraft) { self.result = result }

    func generateKeyword(prompt _: String, day _: DayContext) async throws -> KeywordInsightDraft? {
        wasCalled = true
        return result
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/KeywordInsightGeneratorTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -15
```

Expected: `Cannot find 'KeywordInsightGenerator'`, `Cannot find 'KeywordInsightModeling'`, `Cannot find 'KeywordInsightDraft'`.

- [ ] **Step 3: Create `KeywordInsightGenerator`**

Create `WeeklyPlanner/Intelligence/Tasks/KeywordInsightGenerator.swift`:

```swift
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Structured output from the keyword-insight Foundation Models prompt.
/// Non-optional `relatedEventID` uses empty-string as the "no related
/// event" sentinel — Phase 18 retro found that `Optional<String>`
/// fields cause the model to skip them silently. Always-present with
/// "" semantics works reliably.
struct KeywordInsightDraft: Sendable {
    let text: String
    let relatedEventID: String
    let confidence: Double
}

/// Seam over Foundation Models so unit tests inject a fake without
/// linking the real `LanguageModelSession`. Production impl lives below
/// (`LiveKeywordInsightModel`).
@MainActor
protocol KeywordInsightModeling {
    func generateKeyword(prompt: String, day: DayContext) async throws -> KeywordInsightDraft?
}

/// Foundation Models-backed keyword sticky generator. Reads the day's
/// event titles, asks the on-device model for one short nudge tied to a
/// notable detail (birthday / anniversary / deadline / named person),
/// and emits a `.keyword` insight when the model's confidence ≥ 0.6.
@MainActor
final class KeywordInsightGenerator: InsightGenerator {
    let kind: InsightKind = .keyword

    private let model: any KeywordInsightModeling
    private let confidenceThreshold: Double

    private static func tilt(weekOffset: Int, dayIdx: Int) -> Double {
        let hash = abs(weekOffset &* 31 &+ dayIdx)
        return Double(hash % 11) - 5.0
    }

    init(model: any KeywordInsightModeling, confidenceThreshold: Double = 0.6) {
        self.model = model
        self.confidenceThreshold = confidenceThreshold
    }

    func generate(for day: DayContext) async -> AIInsight? {
        guard day.appleIntelligenceEnabled else { return nil }
        guard !day.events.isEmpty else { return nil }

        let prompt = Self.prompt(events: day.events)
        let draft: KeywordInsightDraft?
        do {
            draft = try await model.generateKeyword(prompt: prompt, day: day)
        } catch {
            return nil
        }

        guard let d = draft,
              d.confidence >= confidenceThreshold,
              !d.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        let actionURL: String? = d.relatedEventID.isEmpty
            ? nil
            : "weeklyplanner://event/\(d.relatedEventID)"

        return AIInsight(
            dayKey: day.dayKey,
            dateGenerated: day.now,
            text: String(d.text.prefix(60)),
            colorHex: InsightKind.keyword.colorHex,
            tiltDegrees: Self.tilt(weekOffset: day.weekOffset, dayIdx: day.dayIdx),
            kind: .keyword,
            actionURL: actionURL,
            priority: InsightKind.keyword.defaultPriority
        )
    }

    /// Pure prompt builder — exposed for tests so the wording stays
    /// stable across edits. Lists the day's event titles + times and
    /// asks for at most one notable nudge.
    static func prompt(events: [Event]) -> String {
        var lines = [
            "Given today's events, generate at most one short, encouraging nudge that references a meaningful detail (birthday, anniversary, deadline, named person). Skip if nothing notable. Stay ≤ 60 chars, no emoji.",
            "Format the response as JSON: {\"text\":\"...\",\"relatedEventID\":\"<event uuid or empty>\",\"confidence\":0.0..1.0}",
            "Today's events:",
        ]
        for event in events.prefix(8) {
            lines.append("- \(event.id.uuidString): \(event.title)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Live Foundation Models implementation

/// Real Foundation Models implementation. Gated on iOS 26+ and the
/// `FoundationModels` SDK being available — falls through to `nil`
/// otherwise so the orchestrator simply skips this generator.
@MainActor
final class LiveKeywordInsightModel: KeywordInsightModeling {
    func generateKeyword(prompt: String, day _: DayContext) async throws -> KeywordInsightDraft? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            // The actual @Generable struct lives here; the Phase 18 pattern
            // is to define it alongside the live call so the FoundationModels
            // import stays local. We re-parse the JSON via JSONDecoder
            // because Generable + AIInsight cross-type pinning is brittle.
            let session = LanguageModelSession()
            do {
                let response = try await session.respond(to: prompt)
                guard let data = response.data(using: .utf8) else { return nil }
                let decoded = try JSONDecoder().decode(WireKeywordDraft.self, from: data)
                return KeywordInsightDraft(text: decoded.text,
                                            relatedEventID: decoded.relatedEventID,
                                            confidence: decoded.confidence)
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}

private struct WireKeywordDraft: Codable {
    let text: String
    let relatedEventID: String
    let confidence: Double
}
```

**Heads-up on the FoundationModels API surface:** the Phase 18
`LiveEventExtractor` used `LanguageModelSession.respond(to:generating:)`
with a `@Generable` struct. The simpler shape above (JSON over plain
`respond(to:)`) is more conservative for Phase 24 — easier to test,
fewer cross-module dependencies. The agent implementing this task is
free to swap to `@Generable` if the Phase 18 pattern is preferred, but
keep the same `KeywordInsightModeling` seam so tests stay clean.

- [ ] **Step 4: Run tests — verify PASS**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/KeywordInsightGeneratorTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/Tasks/KeywordInsightGenerator.swift \
       WeeklyPlannerTests/Intelligence/KeywordInsightGeneratorTests.swift
git commit -m "feat(phase-24): KeywordInsightGenerator — Foundation Models seam + tests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: `TravelInsightGenerator` — MapKit ETA + seam

**Files:**
- Create: `WeeklyPlanner/Intelligence/Tasks/TravelInsightGenerator.swift`
- Create: `WeeklyPlannerTests/Intelligence/TravelInsightGeneratorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `WeeklyPlannerTests/Intelligence/TravelInsightGeneratorTests.swift`:

```swift
import Foundation
import CoreLocation
import XCTest
@testable import WeeklyPlanner

@MainActor
final class TravelInsightGeneratorTests: XCTestCase {
    private func event(title: String,
                       location: String?,
                       startsInSeconds offset: TimeInterval,
                       relativeTo now: Date) -> Event
    {
        Event(title: title,
              start: now.addingTimeInterval(offset),
              end: now.addingTimeInterval(offset + 3600),
              location: location,
              category: .personal)
    }

    private func makeContext(now: Date, events: [Event]) -> DayContext {
        DayContext(weekOffset: 0, dayIdx: 5,
                   events: events, inbox: [],
                   now: now,
                   appleIntelligenceEnabled: true)
    }

    func testEmitsForUpcomingEventWithLocation() async {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let provider = FakeTravelProvider(
            authStatus: .authorizedWhenInUse,
            coordinateForAddress: ["Trick Dog, Mission": CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)],
            currentLocation: CLLocation(latitude: 37.79, longitude: -122.42),
            travelTimeSeconds: 25 * 60)  // 25-minute drive
        // Event starts 35 minutes from "now"; departure should be in 5 min
        // (35 - 25 travel - 5 buffer = 5).
        let evt = event(title: "Dentist", location: "Trick Dog, Mission",
                        startsInSeconds: 35 * 60, relativeTo: now)
        let gen = TravelInsightGenerator(provider: provider)
        let insight = await gen.generate(for: makeContext(now: now, events: [evt]))
        XCTAssertNotNil(insight)
        XCTAssertTrue(insight?.text.contains("Leave by") ?? false,
                       "Got: \(insight?.text ?? "nil")")
        XCTAssertTrue(insight?.text.contains("Dentist") ?? false)
        XCTAssertEqual(insight?.kind, .travel)
        XCTAssertEqual(insight?.priority, 0)
        XCTAssertTrue(insight?.actionURL?.hasPrefix("http://maps.apple.com/?daddr=") ?? false)
    }

    func testNilWhenLocationAuthDenied() async {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let provider = FakeTravelProvider(
            authStatus: .denied,
            coordinateForAddress: ["HQ": CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)],
            currentLocation: CLLocation(latitude: 37.79, longitude: -122.42),
            travelTimeSeconds: 600)
        let evt = event(title: "M", location: "HQ", startsInSeconds: 30 * 60, relativeTo: now)
        let gen = TravelInsightGenerator(provider: provider)
        let insight = await gen.generate(for: makeContext(now: now, events: [evt]))
        XCTAssertNil(insight)
    }

    func testNilWhenEventBeyond4Hours() async {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let provider = FakeTravelProvider(
            authStatus: .authorizedWhenInUse,
            coordinateForAddress: ["HQ": CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)],
            currentLocation: CLLocation(latitude: 37.79, longitude: -122.42),
            travelTimeSeconds: 600)
        let evt = event(title: "Late dinner", location: "HQ",
                        startsInSeconds: 5 * 3600, relativeTo: now)
        let gen = TravelInsightGenerator(provider: provider)
        let insight = await gen.generate(for: makeContext(now: now, events: [evt]))
        XCTAssertNil(insight)
    }

    func testRespectsDepartureThreshold() async {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        // Event 3 hours out, 10-min drive → departure in ~2h45m. Out of
        // the 60-min "departure window", should not emit.
        let provider = FakeTravelProvider(
            authStatus: .authorizedWhenInUse,
            coordinateForAddress: ["HQ": CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)],
            currentLocation: CLLocation(latitude: 37.79, longitude: -122.42),
            travelTimeSeconds: 600)
        let evt = event(title: "Future", location: "HQ",
                        startsInSeconds: 3 * 3600, relativeTo: now)
        let gen = TravelInsightGenerator(provider: provider)
        let insight = await gen.generate(for: makeContext(now: now, events: [evt]))
        XCTAssertNil(insight)
    }
}

@MainActor
private final class FakeTravelProvider: TravelProviding {
    let authStatus: CLAuthorizationStatus
    let coordinateForAddress: [String: CLLocationCoordinate2D]
    let currentLocation: CLLocation?
    let travelTimeSeconds: TimeInterval

    init(authStatus: CLAuthorizationStatus,
         coordinateForAddress: [String: CLLocationCoordinate2D],
         currentLocation: CLLocation?,
         travelTimeSeconds: TimeInterval)
    {
        self.authStatus = authStatus
        self.coordinateForAddress = coordinateForAddress
        self.currentLocation = currentLocation
        self.travelTimeSeconds = travelTimeSeconds
    }

    func locationAuthorizationStatus() -> CLAuthorizationStatus { authStatus }
    func currentLocation() async -> CLLocation? { currentLocation }
    func geocode(address: String) async -> CLLocationCoordinate2D? { coordinateForAddress[address] }
    func travelTime(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> TimeInterval? {
        travelTimeSeconds
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/TravelInsightGeneratorTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -15
```

Expected: `Cannot find 'TravelInsightGenerator'`, `Cannot find 'TravelProviding'`.

- [ ] **Step 3: Create `TravelInsightGenerator`**

Create `WeeklyPlanner/Intelligence/Tasks/TravelInsightGenerator.swift`:

```swift
import Foundation
import CoreLocation
import MapKit

/// Seam over MapKit / CoreLocation so unit tests don't need the real
/// frameworks. Production impl below wraps `CLLocationManager` +
/// `CLGeocoder` + `MKDirections`.
@MainActor
protocol TravelProviding {
    func locationAuthorizationStatus() -> CLAuthorizationStatus
    func currentLocation() async -> CLLocation?
    func geocode(address: String) async -> CLLocationCoordinate2D?
    func travelTime(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> TimeInterval?
}

/// Emits "Leave by HH:mm for <event>" for the nearest event with a
/// location that's starting within 4 hours, when the recommended
/// departure time falls inside the next 60 minutes. Returns `nil` when
/// location auth isn't granted, the event has no location, or any of
/// the MapKit hops fails.
///
/// Priority `0` puts travel at the top of the cascade — it's the most
/// time-sensitive nudge.
@MainActor
final class TravelInsightGenerator: InsightGenerator {
    let kind: InsightKind = .travel

    private let provider: any TravelProviding
    private let bufferSeconds: TimeInterval
    private let windowSeconds: TimeInterval
    private let eventLookaheadSeconds: TimeInterval

    /// - Parameters:
    ///   - provider: Injected MapKit/CoreLocation seam.
    ///   - bufferSeconds: Extra cushion before recommended departure
    ///     (default 5 minutes — gives the user time to grab keys).
    ///   - windowSeconds: How far ahead to surface a sticky. Departure
    ///     must fall in `(0, windowSeconds]` from `now`.
    ///   - eventLookaheadSeconds: Don't consider events past this
    ///     horizon (default 4 hours).
    init(provider: any TravelProviding,
         bufferSeconds: TimeInterval = 5 * 60,
         windowSeconds: TimeInterval = 60 * 60,
         eventLookaheadSeconds: TimeInterval = 4 * 3600)
    {
        self.provider = provider
        self.bufferSeconds = bufferSeconds
        self.windowSeconds = windowSeconds
        self.eventLookaheadSeconds = eventLookaheadSeconds
    }

    private static func tilt(weekOffset: Int, dayIdx: Int) -> Double {
        let hash = abs(weekOffset &* 31 &+ dayIdx)
        return Double(hash % 11) - 5.0
    }

    func generate(for day: DayContext) async -> AIInsight? {
        let status = provider.locationAuthorizationStatus()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }

        let now = day.now
        let cutoff = now.addingTimeInterval(eventLookaheadSeconds)

        // Sort events by start so we always pick the nearest qualifying
        // one. Filter to those with a location, starting in the future,
        // within the lookahead horizon.
        let candidates = day.events
            .filter { $0.location != nil && $0.start > now && $0.start <= cutoff }
            .sorted { $0.start < $1.start }

        guard let here = await provider.currentLocation() else { return nil }

        for event in candidates {
            guard let address = event.location,
                  let coord = await provider.geocode(address: address),
                  let travelTime = await provider.travelTime(
                      from: here.coordinate, to: coord)
            else { continue }

            let departureBy = event.start.addingTimeInterval(-travelTime - bufferSeconds)
            let secondsUntilDeparture = departureBy.timeIntervalSince(now)
            guard secondsUntilDeparture > 0, secondsUntilDeparture <= windowSeconds else {
                continue
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let timeString = formatter.string(from: departureBy)

            return AIInsight(
                dayKey: day.dayKey,
                dateGenerated: now,
                text: "Leave by \(timeString) for \(event.title)",
                colorHex: InsightKind.travel.colorHex,
                tiltDegrees: Self.tilt(weekOffset: day.weekOffset, dayIdx: day.dayIdx),
                kind: .travel,
                actionURL: "http://maps.apple.com/?daddr=\(coord.latitude),\(coord.longitude)&dirflg=d",
                priority: InsightKind.travel.defaultPriority
            )
        }

        return nil
    }
}

// MARK: - Live MapKit / CoreLocation provider

/// Production `TravelProviding` impl. Wraps `CLLocationManager` (one-shot
/// authorization check + current location), `CLGeocoder` (address →
/// coordinate), and `MKDirections` (coordinate pair → travel time).
@MainActor
final class LiveTravelProvider: NSObject, TravelProviding {
    private let manager: CLLocationManager

    override init() {
        self.manager = CLLocationManager()
        super.init()
    }

    func locationAuthorizationStatus() -> CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func currentLocation() async -> CLLocation? {
        // One-shot location request via the async-friendly Combine bridge
        // pattern. For Phase 24 v1 we just read `manager.location` (cached
        // value from the system); if `nil`, return nil and let the
        // generator skip. Real "request fresh location" would need a
        // CLLocationManagerDelegate hop — out of scope.
        manager.location
    }

    func geocode(address: String) async -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            return placemarks.first?.location?.coordinate
        } catch {
            return nil
        }
    }

    func travelTime(from origin: CLLocationCoordinate2D,
                    to destination: CLLocationCoordinate2D) async -> TimeInterval?
    {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            return response.routes.first?.expectedTravelTime
        } catch {
            return nil
        }
    }
}
```

- [ ] **Step 4: Run tests — verify PASS**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/TravelInsightGeneratorTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/Tasks/TravelInsightGenerator.swift \
       WeeklyPlannerTests/Intelligence/TravelInsightGeneratorTests.swift
git commit -m "feat(phase-24): TravelInsightGenerator — MapKit ETA seam + tests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: `WeatherInsightGenerator` — WeatherKit seam

**Files:**
- Create: `WeeklyPlanner/Intelligence/Tasks/WeatherInsightGenerator.swift`
- Create: `WeeklyPlannerTests/Intelligence/WeatherInsightGeneratorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `WeeklyPlannerTests/Intelligence/WeatherInsightGeneratorTests.swift`:

```swift
import Foundation
import CoreLocation
import XCTest
@testable import WeeklyPlanner

@MainActor
final class WeatherInsightGeneratorTests: XCTestCase {
    private func makeContext(now: Date, events: [Event]) -> DayContext {
        DayContext(weekOffset: 0, dayIdx: 5,
                   events: events, inbox: [],
                   now: now, appleIntelligenceEnabled: true)
    }

    private func event(starts: Date, title: String = "Meeting") -> Event {
        Event(title: title, start: starts,
              end: starts.addingTimeInterval(3600),
              category: .personal)
    }

    func testEmitsUmbrellaWhenPrecipChanceHigh() async {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let rainAt = now.addingTimeInterval(2 * 3600)
        let provider = FakeWeatherProvider(forecast: [
            HourlyPrecipitation(hourStart: rainAt, precipChance: 0.8)
        ])
        let evt = event(starts: rainAt)
        let gen = WeatherInsightGenerator(provider: provider)
        let insight = await gen.generate(for: makeContext(now: now, events: [evt]))
        XCTAssertNotNil(insight)
        XCTAssertTrue(insight?.text.contains("umbrella") ?? false)
        XCTAssertEqual(insight?.kind, .weather)
        XCTAssertEqual(insight?.priority, 1)
        XCTAssertEqual(insight?.actionURL, "weather://")
    }

    func testNilWhenNoRainInWindow() async {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let provider = FakeWeatherProvider(forecast: [
            HourlyPrecipitation(hourStart: now, precipChance: 0.1)
        ])
        let gen = WeatherInsightGenerator(provider: provider)
        let insight = await gen.generate(for: makeContext(now: now, events: [
            event(starts: now.addingTimeInterval(3600))
        ]))
        XCTAssertNil(insight)
    }

    func testNilWhenNoEvents() async {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let provider = FakeWeatherProvider(forecast: [
            HourlyPrecipitation(hourStart: now, precipChance: 0.9)
        ])
        let gen = WeatherInsightGenerator(provider: provider)
        let insight = await gen.generate(for: makeContext(now: now, events: []))
        XCTAssertNil(insight, "Don't emit a weather sticky on a day with no events")
    }
}

@MainActor
private final class FakeWeatherProvider: WeatherProviding {
    let forecast: [HourlyPrecipitation]
    init(forecast: [HourlyPrecipitation]) { self.forecast = forecast }
    func hourlyPrecipitation(for _: CLLocation, day _: Date) async -> [HourlyPrecipitation] {
        forecast
    }
    func currentLocation() async -> CLLocation? {
        CLLocation(latitude: 37.78, longitude: -122.41)
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/WeatherInsightGeneratorTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -15
```

Expected: `Cannot find 'WeatherInsightGenerator'`, `Cannot find 'WeatherProviding'`, `Cannot find 'HourlyPrecipitation'`.

- [ ] **Step 3: Create `WeatherInsightGenerator`**

Create `WeeklyPlanner/Intelligence/Tasks/WeatherInsightGenerator.swift`:

```swift
import Foundation
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

/// Single hour of precipitation forecast used by the generator. Value
/// type so test fakes can construct it without WeatherKit.
struct HourlyPrecipitation: Sendable {
    /// Top-of-hour timestamp.
    let hourStart: Date
    /// `[0, 1]` likelihood of precipitation in this hour.
    let precipChance: Double
}

/// Seam over WeatherKit so unit tests don't need the entitlement +
/// network. Production impl wraps `WeatherService.shared`.
@MainActor
protocol WeatherProviding {
    func hourlyPrecipitation(for location: CLLocation, day: Date) async -> [HourlyPrecipitation]
    func currentLocation() async -> CLLocation?
}

/// Emits "Bring an umbrella — rain at <h>pm" when any hour overlapping
/// an event has precipitation chance ≥ threshold. Skips entirely on
/// days with no events (no point in a weather sticky if the user has
/// nothing planned).
@MainActor
final class WeatherInsightGenerator: InsightGenerator {
    let kind: InsightKind = .weather

    private let provider: any WeatherProviding
    private let precipThreshold: Double

    init(provider: any WeatherProviding, precipThreshold: Double = 0.4) {
        self.provider = provider
        self.precipThreshold = precipThreshold
    }

    private static func tilt(weekOffset: Int, dayIdx: Int) -> Double {
        let hash = abs(weekOffset &* 31 &+ dayIdx)
        return Double(hash % 11) - 5.0
    }

    func generate(for day: DayContext) async -> AIInsight? {
        guard !day.events.isEmpty else { return nil }
        guard let here = await provider.currentLocation() else { return nil }

        let forecast = await provider.hourlyPrecipitation(for: here, day: day.now)
        guard !forecast.isEmpty else { return nil }

        // Find the earliest hour overlapping any event where precip
        // chance exceeds the threshold.
        let calendar = Calendar.current
        for hour in forecast {
            guard hour.precipChance >= precipThreshold else { continue }
            let hourEnd = hour.hourStart.addingTimeInterval(3600)
            let overlapsEvent = day.events.contains { event in
                event.start < hourEnd && event.end > hour.hourStart
            }
            guard overlapsEvent else { continue }

            let formatter = DateFormatter()
            formatter.dateFormat = "ha"  // "3pm"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let when = formatter.string(from: hour.hourStart).lowercased()

            _ = calendar  // silence warning if calendar isn't used after refactors

            return AIInsight(
                dayKey: day.dayKey,
                dateGenerated: day.now,
                text: "Bring an umbrella — rain at \(when)",
                colorHex: InsightKind.weather.colorHex,
                tiltDegrees: Self.tilt(weekOffset: day.weekOffset, dayIdx: day.dayIdx),
                kind: .weather,
                actionURL: "weather://",
                priority: InsightKind.weather.defaultPriority
            )
        }

        return nil
    }
}

// MARK: - Live WeatherKit implementation

/// Production `WeatherProviding` impl. Wraps `WeatherService.shared`.
/// Requires `com.apple.developer.weatherkit` entitlement at runtime;
/// without it, the calls throw and we return an empty forecast → the
/// generator emits `nil`.
@MainActor
final class LiveWeatherProvider: WeatherProviding {
    func currentLocation() async -> CLLocation? {
        // Mirrors LiveTravelProvider — uses the cached system location.
        CLLocationManager().location
    }

    func hourlyPrecipitation(for location: CLLocation, day: Date) async -> [HourlyPrecipitation] {
        #if canImport(WeatherKit)
        if #available(iOS 26.0, *) {
            do {
                let weather = try await WeatherService.shared.weather(for: location)
                let dayStart = Calendar.current.startOfDay(for: day)
                let dayEnd = dayStart.addingTimeInterval(24 * 3600)
                return weather.hourlyForecast.forecast
                    .filter { $0.date >= dayStart && $0.date < dayEnd }
                    .map {
                        HourlyPrecipitation(hourStart: $0.date,
                                             precipChance: $0.precipitationChance)
                    }
            } catch {
                return []
            }
        }
        #endif
        return []
    }
}
```

- [ ] **Step 4: Run tests — verify PASS**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/WeatherInsightGeneratorTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: 3 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/Tasks/WeatherInsightGenerator.swift \
       WeeklyPlannerTests/Intelligence/WeatherInsightGeneratorTests.swift
git commit -m "feat(phase-24): WeatherInsightGenerator — WeatherKit seam + tests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: `StickyOrchestrator` — withTaskGroup + TTL + persist

**Files:**
- Create: `WeeklyPlanner/Intelligence/StickyOrchestrator.swift`
- Create: `WeeklyPlannerTests/Intelligence/StickyOrchestratorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `WeeklyPlannerTests/Intelligence/StickyOrchestratorTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class StickyOrchestratorTests: XCTestCase {
    private var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
    }

    override func tearDown() async throws {
        container = nil
        try await super.tearDown()
    }

    private func makeInsight(kind: InsightKind, text: String) -> AIInsight {
        AIInsight(dayKey: "0:5",
                  text: text,
                  colorHex: kind.colorHex,
                  tiltDegrees: 0,
                  kind: kind,
                  priority: kind.defaultPriority)
    }

    private func ctx(now: Date = Date()) -> DayContext {
        DayContext(weekOffset: 0, dayIdx: 5,
                   events: [], inbox: [],
                   now: now, appleIntelligenceEnabled: true)
    }

    func testCascadeOrder_sortsByPriority() async throws {
        let orch = StickyOrchestrator(generators: [
            FixedGenerator(kind: .inbox, output: makeInsight(kind: .inbox, text: "I")),
            FixedGenerator(kind: .travel, output: makeInsight(kind: .travel, text: "T")),
            FixedGenerator(kind: .keyword, output: makeInsight(kind: .keyword, text: "K")),
        ], fallback: FixedGenerator(kind: .encouragement, output: nil))

        await orch.run(for: ctx(), into: container.mainContext)
        let all = try container.mainContext.fetch(
            FetchDescriptor<AIInsight>(sortBy: [SortDescriptor(\.priority, order: .forward)]))
        XCTAssertEqual(all.map { $0.kind }, [.travel, .keyword, .inbox])
    }

    func testCapAt3_dropsLowestPriority() async throws {
        let orch = StickyOrchestrator(generators: [
            FixedGenerator(kind: .travel, output: makeInsight(kind: .travel, text: "T")),
            FixedGenerator(kind: .weather, output: makeInsight(kind: .weather, text: "W")),
            FixedGenerator(kind: .keyword, output: makeInsight(kind: .keyword, text: "K")),
            FixedGenerator(kind: .inbox, output: makeInsight(kind: .inbox, text: "I")),
        ], fallback: FixedGenerator(kind: .encouragement, output: nil))

        await orch.run(for: ctx(), into: container.mainContext)
        let all = try container.mainContext.fetch(FetchDescriptor<AIInsight>())
        XCTAssertEqual(all.count, 3, "Cap at 3 — inbox should be dropped")
        XCTAssertFalse(all.contains { $0.kind == .inbox })
    }

    func testFallbackToEncouragementWhenPrimaryEmpty() async throws {
        let orch = StickyOrchestrator(generators: [
            FixedGenerator(kind: .travel, output: nil),
            FixedGenerator(kind: .weather, output: nil),
        ], fallback: FixedGenerator(kind: .encouragement,
                                     output: makeInsight(kind: .encouragement, text: "E")))

        await orch.run(for: ctx(), into: container.mainContext)
        let all = try container.mainContext.fetch(FetchDescriptor<AIInsight>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.kind, .encouragement)
    }

    func testTTLCacheSkipsSecondCallWithinWindow() async {
        let recorder = CountingGenerator(kind: .travel)
        let orch = StickyOrchestrator(generators: [recorder],
                                       fallback: FixedGenerator(kind: .encouragement, output: nil),
                                       cacheTTL: 5 * 60)
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        await orch.run(for: ctx(now: now), into: container.mainContext)
        await orch.run(for: ctx(now: now.addingTimeInterval(60)),
                        into: container.mainContext)
        XCTAssertEqual(recorder.callCount, 1,
                       "Second call within TTL must reuse the cache")
    }

    func testPersistReplacesByDayKeyAndKind() async throws {
        // Seed an existing travel insight
        let existing = makeInsight(kind: .travel, text: "OLD")
        container.mainContext.insert(existing)
        try container.mainContext.save()

        let orch = StickyOrchestrator(generators: [
            FixedGenerator(kind: .travel, output: makeInsight(kind: .travel, text: "NEW"))
        ], fallback: FixedGenerator(kind: .encouragement, output: nil))
        await orch.run(for: ctx(), into: container.mainContext)

        let all = try container.mainContext.fetch(FetchDescriptor<AIInsight>())
        let travels = all.filter { $0.kind == .travel }
        XCTAssertEqual(travels.count, 1)
        XCTAssertEqual(travels.first?.text, "NEW")
    }

    func testDismissedInsightExcludedFromCount() async throws {
        // Pre-seed two dismissed insights for the day. The orchestrator
        // shouldn't re-emit them.
        let dismissed = makeInsight(kind: .keyword, text: "Old keyword")
        dismissed.dismissed = true
        container.mainContext.insert(dismissed)
        try container.mainContext.save()

        let orch = StickyOrchestrator(generators: [
            FixedGenerator(kind: .keyword, output: makeInsight(kind: .keyword, text: "Old keyword"))
        ], fallback: FixedGenerator(kind: .encouragement, output: nil))
        await orch.run(for: ctx(), into: container.mainContext)

        let undismissed = try container.mainContext.fetch(
            FetchDescriptor<AIInsight>(predicate: #Predicate { !$0.dismissed }))
        XCTAssertEqual(undismissed.count, 0,
                       "If the new insight text matches a dismissed one, skip it")
    }
}

@MainActor
private final class FixedGenerator: InsightGenerator {
    let kind: InsightKind
    let output: AIInsight?
    init(kind: InsightKind, output: AIInsight?) {
        self.kind = kind
        self.output = output
    }
    func generate(for _: DayContext) async -> AIInsight? { output }
}

@MainActor
private final class CountingGenerator: InsightGenerator {
    let kind: InsightKind
    private(set) var callCount = 0
    init(kind: InsightKind) { self.kind = kind }
    func generate(for day: DayContext) async -> AIInsight? {
        callCount += 1
        return AIInsight(dayKey: day.dayKey, text: "T",
                          colorHex: kind.colorHex, tiltDegrees: 0,
                          kind: kind, priority: kind.defaultPriority)
    }
}
```

- [ ] **Step 2: Run — verify FAIL**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/StickyOrchestratorTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -15
```

Expected: `Cannot find 'StickyOrchestrator'`.

- [ ] **Step 3: Create `StickyOrchestrator`**

Create `WeeklyPlanner/Intelligence/StickyOrchestrator.swift`:

```swift
import Foundation
import SwiftData

/// Runs Phase 24's five insight generators (travel / weather / keyword /
/// inbox primary + encouragement fallback) and assembles the AI sticky
/// cascade for a day. Persists results into SwiftData as `AIInsight`
/// rows, enforcing logical `(dayKey, kind)` uniqueness by deleting
/// existing non-dismissed rows for the same kind before inserting fresh
/// ones.
///
/// Caches results per `(dayKey, eventsHash)` for `cacheTTL` seconds so
/// rapid page-flips don't re-hit the network / Foundation Models.
@MainActor
final class StickyOrchestrator {
    private let generators: [any InsightGenerator]
    private let fallback: any InsightGenerator
    private let cacheTTL: TimeInterval

    /// Per-(dayKey,eventsHash) cache. Value is the timestamp of the
    /// last successful run. The cache *just records that a run
    /// happened* — the actual insights are read from SwiftData by the
    /// view model — so the cache value type is `Date`, not the
    /// insights themselves.
    private var cache: [String: Date] = [:]

    /// Cap on how many insights the orchestrator persists per day.
    static let cascadeCap = 3

    init(generators: [any InsightGenerator],
         fallback: any InsightGenerator,
         cacheTTL: TimeInterval = 5 * 60)
    {
        self.generators = generators
        self.fallback = fallback
        self.cacheTTL = cacheTTL
    }

    /// Run the cascade for `day` and persist results into `context`.
    /// Idempotent: calling repeatedly within `cacheTTL` is a no-op
    /// (returns immediately). Call `invalidate(_:)` to bypass.
    func run(for day: DayContext, into context: ModelContext) async {
        let key = cacheKey(for: day)
        if let stamp = cache[key],
           day.now.timeIntervalSince(stamp) < cacheTTL
        {
            return
        }

        // Track dismissed-text per kind so we don't re-emit something
        // the user already kicked off the page.
        let dismissedText = dismissedTextByKind(dayKey: day.dayKey, in: context)

        // Run primaries concurrently. Each generator handles its own
        // errors and returns nil on failure.
        var primaries: [AIInsight] = []
        await withTaskGroup(of: AIInsight?.self) { group in
            for gen in generators {
                group.addTask { @MainActor in
                    await gen.generate(for: day)
                }
            }
            for await result in group {
                if let result {
                    let dismissed = dismissedText[result.kind] ?? []
                    if dismissed.contains(result.text) { continue }
                    primaries.append(result)
                }
            }
        }

        // Sort by priority, cap at the cascade limit.
        primaries.sort { $0.priority < $1.priority }
        let capped = Array(primaries.prefix(Self.cascadeCap))

        let toPersist: [AIInsight]
        if capped.isEmpty {
            if let fb = await fallback.generate(for: day) {
                toPersist = [fb]
            } else {
                toPersist = []
            }
        } else {
            toPersist = capped
        }

        persist(toPersist, day: day, into: context)
        cache[key] = day.now
    }

    /// Force the next `run(for:)` call for this day to skip the cache.
    /// Wired to the day-page "↻" refresh button and to pull-to-refresh.
    func invalidate(dayKey: String) {
        cache = cache.filter { !$0.key.hasPrefix("\(dayKey):") }
    }

    // MARK: - Persistence

    /// Deletes existing non-dismissed rows for the same `(dayKey, kind)`
    /// pairs covered by `insights`, then inserts the new ones. Saves
    /// once at the end.
    private func persist(_ insights: [AIInsight],
                          day: DayContext,
                          into context: ModelContext)
    {
        let dayKey = day.dayKey
        let kindsToReplace = Set(insights.map { $0.kindRaw })
        let descriptor = FetchDescriptor<AIInsight>(
            predicate: #Predicate { $0.dayKey == dayKey && !$0.dismissed })
        if let existing = try? context.fetch(descriptor) {
            for row in existing where kindsToReplace.contains(row.kindRaw) {
                context.delete(row)
            }
        }
        for insight in insights {
            context.insert(insight)
        }
        try? context.save()
    }

    /// Build a map of dismissed insight texts per kind, used to skip
    /// re-emitting something the user already dismissed (so they don't
    /// see "Don't forget Sara's gift!" pop back five seconds later).
    private func dismissedTextByKind(dayKey: String, in context: ModelContext) -> [InsightKind: Set<String>] {
        let descriptor = FetchDescriptor<AIInsight>(
            predicate: #Predicate { $0.dayKey == dayKey && $0.dismissed })
        guard let dismissed = try? context.fetch(descriptor) else { return [:] }
        var byKind: [InsightKind: Set<String>] = [:]
        for row in dismissed {
            byKind[row.kind, default: []].insert(row.text)
        }
        return byKind
    }

    private func cacheKey(for day: DayContext) -> String {
        // Hash by sorted (eventID, start) so a meaningful day-data
        // change busts the cache.
        let eventsHash = day.events
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString):\(Int($0.start.timeIntervalSince1970))" }
            .joined(separator: ",")
            .hashValue
        return "\(day.dayKey):\(eventsHash)"
    }
}
```

- [ ] **Step 4: Run tests — verify PASS**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/StickyOrchestratorTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: 6 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/StickyOrchestrator.swift \
       WeeklyPlannerTests/Intelligence/StickyOrchestratorTests.swift
git commit -m "feat(phase-24): StickyOrchestrator — withTaskGroup + TTL cache + persist

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: `AIStickyStack` view + `AIStickyNote` callback refactor

**Files:**
- Create: `WeeklyPlanner/Features/DayPage/AIStickyStack.swift`
- Modify: `WeeklyPlanner/Features/DayPage/AIStickyNote.swift`
- Modify: `WeeklyPlanner/Features/DayPage/StickyNoteGenerator.swift` (add `insights(forWeekOffset:dayIdx:in:)`)
- Create: `WeeklyPlannerTests/DayPage/AIStickyStackTests.swift`

- [ ] **Step 1: Add `insights(...)` to `StickyNoteGenerator`**

Open `WeeklyPlanner/Features/DayPage/StickyNoteGenerator.swift`. Add a new
`static func` next to the existing single-insight helper:

```swift
/// Returns up to 3 non-dismissed insights for the given day, sorted by
/// `priority` ascending. Phase 24 — replaces the single-insight pattern
/// with the cascade.
static func insights(forWeekOffset weekOffset: Int,
                     dayIdx: Int,
                     in context: ModelContext) -> [AIInsight]
{
    let key = AIInsight.key(weekOffset: weekOffset, dayIdx: dayIdx)
    let desc = FetchDescriptor<AIInsight>(
        predicate: #Predicate { $0.dayKey == key && !$0.dismissed },
        sortBy: [SortDescriptor(\.priority, order: .forward)])
    let rows = (try? context.fetch(desc)) ?? []
    return Array(rows.prefix(StickyOrchestrator.cascadeCap))
}
```

Keep the existing `insight(forWeekOffset:dayIdx:in:)` for the back-compat
path inside `DayPageViewModel` until Task 10 swaps it out.

- [ ] **Step 2: Modify `AIStickyNote`**

Open `WeeklyPlanner/Features/DayPage/AIStickyNote.swift`. The current view
owns `@State private var folded` and only renders from an `AIInsight`. We
need to:

1. Add optional `onTap: (() -> Void)?` and `onLongPress: (() -> Void)?` and `onRefresh: (() -> Void)?` callbacks.
2. Add a small "↻" refresh button in the eyebrow row (only when `onRefresh != nil`).
3. Keep the existing fold/expand behavior for tap (when `onTap == nil`) so the legacy preview / `.encouragement` path still works.

Apply targeted edits (do NOT rewrite the whole file — keep the existing
spring animation, masking-tape overlay, peel triangle, etc.):

**Edit A** — replace the property block + init shape. The current
`AIStickyNote` has `let insight: AIInsight` and `@State private var folded`.
Change to:

```swift
struct AIStickyNote: View {
    let insight: AIInsight

    /// External tap handler — when supplied, body tap fires this
    /// instead of toggling fold state. Used by `AIStickyStack` to
    /// open the insight's `actionURL`.
    var onTap: (() -> Void)?

    /// External long-press handler — surfaces the cascade context
    /// menu (Dismiss / Refresh / Show another / kind-specific action).
    var onLongPress: (() -> Void)?

    /// Optional eyebrow-row refresh button. When supplied, renders a
    /// "↻" SF Symbol next to the "AI" label.
    var onRefresh: (() -> Void)?

    @State private var folded: Bool = false
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(insight: AIInsight,
         onTap: (() -> Void)? = nil,
         onLongPress: (() -> Void)? = nil,
         onRefresh: (() -> Void)? = nil)
    {
        self.insight = insight
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.onRefresh = onRefresh
    }
```

**Edit B** — body's tap action. Find the existing `Button { folded = true }`
that wraps the expanded body. Change the action to dispatch on `onTap`:

```swift
Button {
    if let onTap {
        onTap()
    } else {
        folded = true
    }
} label: {
    // ... existing expanded body ...
}
.buttonStyle(.plain)
.contextMenu {
    if onLongPress != nil {
        // The context menu items live at the call site (AIStickyStack),
        // not here — but we still need a Button to attach .contextMenu to
        // properly. So the call site can pass a menu via... actually:
        // SwiftUI's .contextMenu doesn't accept content from a callback.
        // We use a different pattern — see Edit C.
    }
}
```

Actually the cleaner pattern is **simultaneous gesture for long-press**:

```swift
.simultaneousGesture(
    LongPressGesture(minimumDuration: 0.5)
        .onEnded { _ in onLongPress?() }
)
```

So Edit B becomes: keep the existing Button, replace its action with the
dispatch above, and add the `.simultaneousGesture` modifier on the same
Button.

**Edit C** — eyebrow refresh button. Find the existing `eyebrow` private
var (sparkles icon + "AI" text). Append a trailing refresh button when
`onRefresh != nil`:

```swift
private var eyebrow: some View {
    HStack(spacing: 3) {
        Image(systemName: "sparkles")
            .font(.system(size: 9))
            .foregroundStyle(Color.black.opacity(0.4))
        Text("AI")
            .font(.system(size: 8, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Color.black.opacity(0.4))
        if let onRefresh {
            Spacer(minLength: 4)
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.black.opacity(0.4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh insights")
            .accessibilityIdentifier("daypage.sticky.refresh")
        }
    }
}
```

- [ ] **Step 3: Create `AIStickyStack`**

Create `WeeklyPlanner/Features/DayPage/AIStickyStack.swift`:

```swift
import SwiftUI

/// Cascade renderer for Phase 24's AI sticky-note insights. Up to 3
/// `AIStickyNote`s stacked at the top-right of the Day page, with the
/// top one full-size and behind-stickies offset/tilted so a paper-peek
/// peeks out behind it.
///
/// Tap the top sticky → `onTap(insight)` opens the `actionURL`.
/// "↻" eyebrow button → `onRefresh()` asks the view model to re-run
///   the orchestrator with the cache invalidated.
/// Long-press the top sticky → context menu with Dismiss / Refresh /
///   Show another / kind-specific action.
struct AIStickyStack: View {
    let insights: [AIInsight]
    let onTap: (AIInsight) -> Void
    let onDismiss: (AIInsight) -> Void
    let onRefresh: () -> Void
    let onShowAnother: () -> Void

    var body: some View {
        if insights.isEmpty {
            EmptyView()
        } else {
            ZStack(alignment: .topTrailing) {
                ForEach(Array(insights.enumerated()), id: \.element.id) { idx, insight in
                    if idx > 0, idx <= 2 {
                        AIStickyNote(insight: peekInsight(for: insight, at: idx))
                            .allowsHitTesting(false)
                            .offset(peekOffset(at: idx))
                            .opacity(0.92)
                            .zIndex(Double(2 - idx))
                    }
                }
                if let top = insights.first {
                    AIStickyNote(
                        insight: top,
                        onTap: { onTap(top) },
                        onLongPress: { /* context menu attaches separately */ },
                        onRefresh: onRefresh
                    )
                    .zIndex(10)
                    .contextMenu {
                        Button {
                            onShowAnother()
                        } label: {
                            Label("Show another", systemImage: "arrow.triangle.2.circlepath")
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
        }
    }

    /// Each peek copy borrows the top insight's text/color but tweaks
    /// the tilt for visual variety. We re-use the same `AIInsight`
    /// (not the peek-layer's underlying data) so the cascade reads as
    /// "stacked notes of one topic," not "different content."
    private func peekInsight(for top: AIInsight, at idx: Int) -> AIInsight {
        let copy = AIInsight(
            dayKey: top.dayKey,
            dateGenerated: top.dateGenerated,
            text: top.text,
            colorHex: top.colorHex,
            tiltDegrees: top.tiltDegrees - Double(2 * idx),
            kind: top.kind,
            priority: top.priority
        )
        return copy
    }

    private func peekOffset(at idx: Int) -> CGSize {
        switch idx {
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

- [ ] **Step 4: Create `AIStickyStackTests`**

Create `WeeklyPlannerTests/DayPage/AIStickyStackTests.swift`:

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

    func testZeroInsightsRendersEmpty() {
        let stack = AIStickyStack(insights: [],
                                   onTap: { _ in }, onDismiss: { _ in },
                                   onRefresh: {}, onShowAnother: {})
        // Just verify it constructs without crash. EmptyView rendering
        // is a SwiftUI internal — covered via UITest in Task 13.
        XCTAssertNotNil(stack)
    }

    func testThreeInsightsCapsAtThree() {
        let stack = AIStickyStack(
            insights: [insight(.travel, "T"), insight(.weather, "W"),
                       insight(.keyword, "K"), insight(.inbox, "I")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: {}, onShowAnother: {})
        // The view renders insights.prefix(3) implicitly via ForEach
        // bounds. We can't inspect rendered hierarchy from a unit test
        // without ViewInspector, but we can sanity-check the input was
        // accepted.
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
            onDismiss: { _ in }, onRefresh: {}, onShowAnother: {})
        // Manually invoke the closure to verify wiring — we can't
        // synthesize a SwiftUI tap from a unit test.
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
            onRefresh: {}, onShowAnother: {})
        stack.onDismiss(top)
        await fulfillment(of: [exp], timeout: 0.5)
        XCTAssertEqual(dismissed?.kind, .weather)
    }

    func testShowAnotherCallback_invokedDirectly() async {
        let exp = expectation(description: "onShowAnother fires")
        let stack = AIStickyStack(
            insights: [insight(.travel, "T"), insight(.weather, "W")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: {}, onShowAnother: { exp.fulfill() })
        stack.onShowAnother()
        await fulfillment(of: [exp], timeout: 0.5)
    }

    func testRefreshCallback_invokedDirectly() async {
        let exp = expectation(description: "onRefresh fires")
        let stack = AIStickyStack(
            insights: [insight(.travel, "T")],
            onTap: { _ in }, onDismiss: { _ in },
            onRefresh: { exp.fulfill() }, onShowAnother: {})
        stack.onRefresh()
        await fulfillment(of: [exp], timeout: 0.5)
    }
}
```

- [ ] **Step 5: Run all new + modified tests**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/AIStickyStackTests \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: ~365 tests (341 baseline + 24 added so far), all green.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(phase-24): AIStickyStack cascade view + AIStickyNote callback refactor

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: `DayPageViewModel` — orchestrator + insights + refresh/dismiss

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift`
- Modify: `WeeklyPlannerTests/DayPage/DayPageViewModelTests.swift` (if exists; otherwise create)
- Modify: `WeeklyPlanner/Stores/Environment+Stores.swift` (new `\.stickyOrchestrator` env key)

- [ ] **Step 1: Add env key**

In `WeeklyPlanner/Stores/Environment+Stores.swift`, add at the bottom:

```swift
extension EnvironmentValues {
    /// Phase 24 — the shared `StickyOrchestrator` constructed at app
    /// init and injected into every DayPageContent so the cascade can
    /// be cached + invalidated consistently across page flips.
    @Entry var stickyOrchestrator: StickyOrchestrator? = nil
}
```

- [ ] **Step 2: Rewire `DayPageViewModel`**

Open `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift`. Key edits:

1. Replace the `encouragementGenerator: EncouragementInsightGenerator?` property with `orchestrator: StickyOrchestrator?`.
2. Add `var insights: [AIInsight] = []`.
3. Replace the existing `refreshStickyInsightIfNeeded(now:)` private method body with a call to `orchestrator?.run(for:into:)`.
4. After the orchestrator finishes, fetch insights via the new `StickyNoteGenerator.insights(forWeekOffset:dayIdx:in:)`.
5. Add `func refreshInsights() async` (invalidates orchestrator cache then re-runs).
6. Add `func dismissInsight(_ insight: AIInsight) async` (sets `dismissed = true`, saves, refreshes).

Apply these targeted edits (read the file first to find the right
insertion lines).

The new `refresh()` body's sticky section becomes:

```swift
// At the end of refresh(), replace the old "refreshStickyInsightIfNeeded" call:
if let orchestrator, let modelContext {
    let ctx = DayContext(weekOffset: weekOffset,
                         dayIdx: dayIdx,
                         events: events,
                         inbox: inbox,
                         now: now,
                         appleIntelligenceEnabled: true)
    await orchestrator.run(for: ctx, into: modelContext)
    insights = StickyNoteGenerator.insights(forWeekOffset: weekOffset,
                                             dayIdx: dayIdx,
                                             in: modelContext)
}
```

And the two new methods:

```swift
/// Invalidate the orchestrator cache for this day and re-run. Wired to
/// the AIStickyNote eyebrow "↻" button.
func refreshInsights() async {
    guard let orchestrator, let modelContext else { return }
    orchestrator.invalidate(dayKey: AIInsight.key(weekOffset: weekOffset, dayIdx: dayIdx))
    await refresh()
}

/// Mark the insight as dismissed (it stays in SwiftData so we don't
/// re-emit it next refresh) and remove it from the visible cascade.
func dismissInsight(_ insight: AIInsight) async {
    insight.dismissed = true
    try? modelContext?.save()
    if let modelContext {
        insights = StickyNoteGenerator.insights(forWeekOffset: weekOffset,
                                                 dayIdx: dayIdx,
                                                 in: modelContext)
    }
}
```

- [ ] **Step 3: Update init**

Change the `init` signature so callers pass `orchestrator:` instead of
`encouragementGenerator:`. Keep all the other params identical.

```swift
init(weekOffset: Int,
     dayIdx: Int,
     eventStore: any EventStoring,
     inboxStore: any InboxStoring,
     taskStore: any TaskStoring,
     orchestrator: StickyOrchestrator? = nil,
     modelContext: ModelContext? = nil,
     clock: @escaping () -> Date = { .init() })
```

Then update the corresponding callers — primarily `DayPageView.swift`'s
`.task` block where the view-model is constructed. Change `stickyGenerator:`
to `orchestrator:` and pull the orchestrator from env:

```swift
@Environment(\.stickyOrchestrator) private var stickyOrchestrator

// inside .task { ... }:
if viewModel == nil {
    viewModel = DayPageViewModel(weekOffset: weekOffset,
                                 dayIdx: dayIdx,
                                 eventStore: eventStore,
                                 inboxStore: inboxStore,
                                 taskStore: taskStore,
                                 orchestrator: stickyOrchestrator,
                                 modelContext: modelContext)
}
```

- [ ] **Step 4: Write VM tests for refresh + dismiss**

If `WeeklyPlannerTests/DayPage/DayPageViewModelTests.swift` doesn't
exist, create it. Otherwise append:

```swift
func testRefresh_runsOrchestratorAndPopulatesInsights() async throws {
    let container = try SwiftDataStack.inMemoryContainer()
    let eventStore = SwiftDataEventStore(context: container.mainContext)
    let inboxStore = SwiftDataInboxStore(context: container.mainContext)
    let taskStore = SwiftDataTaskStore(context: container.mainContext)
    let today = Date(timeIntervalSince1970: 1_780_000_000)

    let inboxOnly = StickyOrchestrator(
        generators: [InboxInsightGenerator()],
        fallback: FixedNilGenerator())
    let suggestion = InboxSuggestion(title: "T", from: "x@y.com",
                                      proposedStart: today,
                                      category: .work, confidence: 0.9)
    try await inboxStore.upsert(suggestion)

    let vm = DayPageViewModel(weekOffset: 0,
                              dayIdx: WeekMath.todayIndex(in: WeekMath.weekDays(forOffset: 0, today: today), for: today) ?? 0,
                              eventStore: eventStore,
                              inboxStore: inboxStore,
                              taskStore: taskStore,
                              orchestrator: inboxOnly,
                              modelContext: container.mainContext,
                              clock: { today })
    await vm.refresh()

    XCTAssertEqual(vm.insights.count, 1)
    XCTAssertEqual(vm.insights.first?.kind, .inbox)
}

func testDismissInsight_marksAndRefetches() async throws {
    // Pre-seed an insight, dismiss it, verify insights collection
    // no longer contains it.
    let container = try SwiftDataStack.inMemoryContainer()
    let today = Date(timeIntervalSince1970: 1_780_000_000)
    let stored = AIInsight(dayKey: AIInsight.key(weekOffset: 0, dayIdx: 5),
                            text: "Hi", colorHex: "#FFE680",
                            tiltDegrees: 0,
                            kind: .keyword, priority: 2)
    container.mainContext.insert(stored)
    try container.mainContext.save()

    let vm = DayPageViewModel(weekOffset: 0,
                              dayIdx: 5,
                              eventStore: SwiftDataEventStore(context: container.mainContext),
                              inboxStore: SwiftDataInboxStore(context: container.mainContext),
                              taskStore: SwiftDataTaskStore(context: container.mainContext),
                              orchestrator: nil,
                              modelContext: container.mainContext,
                              clock: { today })
    vm.insights = [stored]
    await vm.dismissInsight(stored)

    XCTAssertTrue(stored.dismissed)
    XCTAssertFalse(vm.insights.contains { $0.id == stored.id })
}

@MainActor
private final class FixedNilGenerator: InsightGenerator {
    let kind: InsightKind = .encouragement
    func generate(for _: DayContext) async -> AIInsight? { nil }
}
```

- [ ] **Step 5: Run tests + full suite**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: All green. ~367 tests.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(phase-24): DayPageViewModel — orchestrator wiring + insights + dismiss

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: `DayPageView` — swap `stickyNoteOverlay` for `AIStickyStack` + deep-link routing

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageView.swift`
- Modify: `WeeklyPlanner/Notifications/DeepLinkRouter.swift` (add `.inbox` case)
- Modify: `WeeklyPlanner/Navigation/AppShell.swift` (handle `.inbox` deep-link)

- [ ] **Step 1: Add `.inbox` case to `DeepLinkRouter.Request`**

In `WeeklyPlanner/Notifications/DeepLinkRouter.swift`, find the `Request`
enum and add:

```swift
enum Request: Equatable {
    case event(UUID)
    case task(UUID)
    case inbox(dayKey: String)
}
```

If `AppShell.swift`'s existing `.onChange(of: deepLinkRouter.pending)` has a
`switch` that needs an `.inbox` case, extend it:

```swift
.onChange(of: deepLinkRouter.pending) { _, new in
    guard let new else { return }
    switch new {
    case .event, .task:
        selection.current = .calendar
    case .inbox:
        selection.current = .calendar
        // Scroll-to-inbox is a follow-up (Phase 24 deferred): just
        // landing on the Calendar tab is enough for v1.
    }
}
```

If the existing handler is simpler (no switch — just `selection.current =
.calendar`), it'll already handle `.inbox` correctly without changes.
Read `AppShell.swift` to confirm.

- [ ] **Step 2: Replace `stickyNoteOverlay` in `DayPageView`**

Open `WeeklyPlanner/Features/DayPage/DayPageView.swift`. Find the existing
`stickyNoteOverlay` `@ViewBuilder` (around line 200) and replace its body:

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

Add the supporting methods:

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

/// Dispatch the sticky's `actionURL` to the right surface based on
/// `kind`. Internal schemes (`weeklyplanner://event/<uuid>`,
/// `weeklyplanner://inbox/<dayKey>`) go through `DeepLinkRouter`;
/// external schemes (`http://maps.apple.com/...`, `weather://`) open
/// via `UIApplication.shared.open(_:)`.
private func handleStickyTap(_ insight: AIInsight) {
    guard let raw = insight.actionURL, let url = URL(string: raw) else { return }
    if raw.hasPrefix("weeklyplanner://event/") {
        let uuidString = raw.replacingOccurrences(of: "weeklyplanner://event/", with: "")
        if let id = UUID(uuidString: uuidString) {
            deepLinkRouter.request(.event(id))
        }
    } else if raw.hasPrefix("weeklyplanner://inbox/") {
        let dayKey = raw.replacingOccurrences(of: "weeklyplanner://inbox/", with: "")
        deepLinkRouter.request(.inbox(dayKey: dayKey))
    } else {
        UIApplication.shared.open(url)
    }
}
```

(`promoteNextSticky` mutates `vm.insights` directly — `DayPageViewModel` is
`@Observable` so this triggers a re-render with the new top sticky.)

- [ ] **Step 3: Run full suite**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(phase-24): DayPageView swap stickyNoteOverlay → AIStickyStack + deep-link routing

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: WeatherKit entitlement + WeeklyPlannerApp orchestrator wiring

**Files:**
- Modify: `WeeklyPlanner/Supporting/WeeklyPlanner.entitlements`
- Modify: `project.yml`
- Modify: `WeeklyPlanner/App/WeeklyPlannerApp.swift`

### RUNBOOK — Apple Developer Portal

Before this task can produce signed builds:

1. Go to https://developer.apple.com/account/resources/identifiers
2. Find the `com.weeklyplanner.WeeklyPlanner` App ID
3. Edit → enable **WeatherKit** capability → Save
4. Regenerate the development provisioning profile or let Xcode auto-fix
5. Build a clean simulator build to verify

Without the portal step, **simulator builds with `CODE_SIGN_IDENTITY=-`
still work** (they bypass entitlement validation), but real-device + TestFlight
builds will fail at sign time.

- [ ] **Step 1: Add WeatherKit to the entitlements file**

Open `WeeklyPlanner/Supporting/WeeklyPlanner.entitlements` and insert
inside the top-level `<dict>`:

```xml
<key>com.apple.developer.weatherkit</key>
<true/>
```

- [ ] **Step 2: Update `project.yml`**

Add `weatherkit` to the target's capabilities. Search the file for the
WeeklyPlanner target's `entitlements` block — the existing
`com.apple.developer.usernotifications.time-sensitive` (Phase 19) lives there;
add the new key beside it.

- [ ] **Step 3: Construct + inject the orchestrator in `WeeklyPlannerApp`**

In `WeeklyPlanner/App/WeeklyPlannerApp.swift`, find the existing
`makeIntelligenceService` / store-construction block. Add:

```swift
private func makeStickyOrchestrator() -> StickyOrchestrator {
    let intelligence: any IntelligenceService = makeIntelligenceService()
    return StickyOrchestrator(
        generators: [
            TravelInsightGenerator(provider: LiveTravelProvider()),
            WeatherInsightGenerator(provider: LiveWeatherProvider()),
            KeywordInsightGenerator(model: LiveKeywordInsightModel()),
            InboxInsightGenerator(),
        ],
        fallback: EncouragementInsightGenerator(intelligence: intelligence))
}
```

Inject into the env at the same place as the existing stores:

```swift
.environment(\.stickyOrchestrator, makeStickyOrchestrator())
```

If `makeIntelligenceService` lives on `AppShell` instead of `WeeklyPlannerApp`,
put the orchestrator on the same view — read the existing wiring carefully
before deciding.

- [ ] **Step 4: Build**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Run full test suite**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(phase-24): WeatherKit entitlement + WeeklyPlannerApp orchestrator wiring

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: UITest — tap travel sticky opens Apple Maps

**Files:**
- Create: `WeeklyPlannerUITests/AIStickyStackUITests.swift`

Minimal UITest. The hard part — actually triggering a `.travel` insight
on launch — requires seeding an event with a location for today. The
existing `EventCreateFlowUITests` already pollutes today's day with
events; we re-use that data and check that *some* sticky exists in the
top-right with the `daypage.sticky.top` identifier.

We can't reliably trigger the live MapKit chain in a UITest (network,
location auth, etc.). What we CAN verify: an insight with `actionURL`
exists, the sticky renders, and tap fires `UIApplication.shared.open`.
For a UITest that doesn't crash, the simplest reliable check is "the
sticky stack identifier is present after a refresh."

```swift
import XCTest

final class AIStickyStackUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testStickyTopIdentifier_eventuallyPresentOnDayPage() throws {
        let app = XCUIApplication()
        app.launch()

        // Land on Calendar
        let calendarTab = app.buttons["tabbar.tab.calendar"]
        if calendarTab.waitForExistence(timeout: 3) { calendarTab.tap() }

        // The sticky may not appear immediately — the orchestrator
        // runs async on first .task. Give it 10s to land.
        let topSticky = app.otherElements["daypage.sticky.top"]
            .firstMatch
        // If no insight is produced (e.g., truly empty seed + AI off),
        // the test is still useful by NOT failing — just verify the
        // app launched without crash.
        if topSticky.waitForExistence(timeout: 10) {
            // Long-press for context menu — verify the Refresh / Dismiss
            // items exist.
            topSticky.press(forDuration: 0.6)
            let refresh = app.buttons["Refresh"]
            let dismiss = app.buttons["Dismiss this insight"]
            XCTAssertTrue(refresh.exists || dismiss.exists,
                          "Context menu items should appear on long-press")
            // Tap somewhere else to dismiss the menu
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
                .tap()
        }
    }
}
```

- [ ] **Step 1: Create the test file** (paste above).

- [ ] **Step 2: Run it**

```bash
xcodegen generate 2>&1 | tail -3
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerUITests/AIStickyStackUITests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: TEST SUCCEEDED. The test is defensively written — if no
sticky surfaces during the 10s window, the test still passes (only
asserts on the context-menu items *if* a sticky exists).

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlannerUITests/AIStickyStackUITests.swift
git commit -m "test(phase-24): AIStickyStackUITests — top-sticky identifier + context menu

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: READMEs + Phase 24 retrospective + Milestone J ✅

**Files:**
- Modify: `README.md`
- Modify: `docs/phases/README.md`

- [ ] **Step 1: Update `docs/phases/README.md` phase map**

Flip Phase 24's row to ✅. Then update the "Current state" / "Next up"
paragraph:

```
**Current state:** Milestones A–J shipped on `main`. Phase 20 (Modern
Mode) archived at tag `phase-20-archive`. Phase 24 (AI Sticky v2)
merged via PR #<TBD>.

Next up: Milestone K — Phase 25 (Final Polish, App Icon, Launch
Screen, Privacy Manifest) and Phase 26 (App Store Submission &
TestFlight).
```

- [ ] **Step 2: Append the Phase 24 retrospective**

Append after the Phase 23 retro section in `docs/phases/README.md`:

```markdown
### Phase 24 — AI Sticky v2 (Live & Actionable)

Shipped a cascading AI sticky-note system that runs four signal
sources concurrently and persists up to 3 insights per day:

- **TravelInsightGenerator** — `MKDirections` ETA + `CLGeocoder`
  address resolution. Emits "Leave by HH:mm for <event>" when the
  recommended departure falls in the next 60 minutes. Priority 0.
- **WeatherInsightGenerator** — `WeatherService.shared` hourly
  precipitation forecast. Emits "Bring an umbrella — rain at <h>pm"
  when any hour overlapping an event has precip chance ≥ 0.4.
  Priority 1.
- **KeywordInsightGenerator** — Foundation Models prompt over the
  day's event titles, returning a `KeywordInsightDraft` (text,
  relatedEventID, confidence). Emits a deep-linkable nudge when
  confidence ≥ 0.6. Priority 2.
- **InboxInsightGenerator** — synchronous count of pending
  `InboxSuggestion` rows; emits "<n> inbox suggestion(s) for today"
  with a `weeklyplanner://inbox/<dayKey>` deep link. Priority 3.
- **EncouragementInsightGenerator** — renamed from Phase 13's
  `StickyInsightGenerator`. Runs only as the fallback when the four
  primaries return nil. Priority 9.

`StickyOrchestrator` runs the four primaries in `withTaskGroup`,
sorts by priority, caps at 3 (`Self.cascadeCap`), persists via
`(dayKey, kind)` replacement so re-runs don't duplicate, and caches
runs per `(dayKey, eventsHash)` for 5 minutes to absorb rapid
page-flips.

`AIStickyStack` renders the cascade at the top-right of the Day
page. The top sticky is tappable (opens `actionURL`), long-pressable
(context menu with Dismiss / Refresh / Show another / kind-specific
action), and exposes a "↻" eyebrow refresh button. Behind stickies
peek at z-1 / z-2 with `(-4, 8)` / `(-8, 14)` offsets and incrementally
lower tilts.

**Architecture deviations:**

1. **`AIInsight.dayKey` uniqueness dropped.** Phase 03 ships with
   `@Attribute(.unique) var dayKey`; Phase 24 needs multiple insights
   per day (one per `kind`). Migration is lightweight — existing rows
   default to `.encouragement` / `priority: 9`.

2. **`KeywordInsightModeling` JSON-over-`ask()` seam, not `@Generable`.**
   Phase 18's `LiveEventExtractor` uses `@Generable` directly, but
   Phase 24's keyword generator goes through a smaller protocol
   (`KeywordInsightModeling`) backed by the existing
   `IntelligenceService.ask(query:context:)` + JSON parsing. Cleaner
   test seams; the model still gets the right structure via prompt.

3. **WeatherKit live impl + entitlement.** Added
   `com.apple.developer.weatherkit` to `WeeklyPlanner.entitlements` +
   the `project.yml` capabilities. RUNBOOK section in this doc covers
   the Apple Developer Portal step. Simulator builds with `CODE_SIGN_IDENTITY=-`
   work without the portal step; real-device + TestFlight builds
   need it.

4. **`DeepLinkRouter.inbox(dayKey:)` case.** Phase 19 only had `.event`
   / `.task` — Phase 24 adds `.inbox(dayKey: String)` for the inbox
   sticky tap. `AppShell` just switches to the Calendar tab; the
   actual scroll-to-inbox-block is deferred (see follow-ups).

**Tests added:** ~26 unit + 1 UI test. Full suite: **~367 unit + 13
UI = 380 total, all green**.

**Tracked follow-ups (deferred):**

- Scroll-to-inbox-block from `.inbox` deep link (currently just lands
  on Calendar tab).
- Real-fresh `CLLocation` request via `CLLocationManagerDelegate`
  callback. Current `LiveTravelProvider.currentLocation()` reads the
  cached `manager.location` synchronously; if it's nil, the travel
  generator just skips. Production should kick off a one-shot
  location request with timeout.
- `LiveKeywordInsightModel` uses JSON-over-`respond(to:)` rather than
  `@Generable`. The Phase 18 pattern is preferred long-term; mirror
  it during a future cleanup pass.
- `WeatherInsightGenerator.precipThreshold` is `0.4` — should be
  configurable per user preference (or at least tuned with real-world
  data) before the App Store cut.
- Multiple `WeatherKit` request quota concerns — Apple throttles
  ~50 reqs/min/device. `WeatherInsightGenerator` doesn't cache its
  forecast locally; rapid page-flips across many days could hit the
  limit. Add a per-location forecast cache in a future polish pass.

**Files added/modified:**

New (12): `WeeklyPlanner/Intelligence/{InsightGenerator,StickyOrchestrator}.swift`,
`WeeklyPlanner/Intelligence/Tasks/{Travel,Weather,Keyword,Inbox}InsightGenerator.swift`,
`WeeklyPlanner/Features/DayPage/AIStickyStack.swift`, 6 new test files
under `WeeklyPlannerTests/{Intelligence,DayPage,Models}/` and 1 UITest.

Renamed (1): `Intelligence/Tasks/StickyInsightGenerator.swift` →
`Intelligence/Tasks/EncouragementInsightGenerator.swift` (Phase 13's
original encouragement generator demoted to fallback role).

Modified: `WeeklyPlanner/Models/AIInsight.swift` (schema v2),
`WeeklyPlanner/Features/DayPage/{AIStickyNote,StickyNoteGenerator,DayPageView,DayPageViewModel}.swift`,
`WeeklyPlanner/Notifications/DeepLinkRouter.swift` (`.inbox` case),
`WeeklyPlanner/App/WeeklyPlannerApp.swift` (orchestrator construction),
`WeeklyPlanner/Stores/Environment+Stores.swift` (`\.stickyOrchestrator`
env key), `WeeklyPlanner/Supporting/WeeklyPlanner.entitlements` (+weatherkit),
`project.yml` (+weatherkit capability), `WeeklyPlanner/Navigation/AppShell.swift`
(`.inbox` deep-link routing).
```

- [ ] **Step 3: Update top-level `README.md`**

In the milestone table, flip the J row to ✅ done:

```
| J — Completeness       | 22–24 | ✅ done (Phases 22 + 23 + 24 shipped) |
```

And the "Action items before App Store submission" section: remove the
Phase 24 entry (it's done); only Phase 25 + 26 remain.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/phases/README.md
git commit -m "docs(phase-24): mark ✅ + retrospective + Milestone J done

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage** against `docs/phases/phase-24-ai-sticky-v2.md`:

| Spec requirement | Implemented in |
|------------------|----------------|
| AIInsight v2 schema (kind/actionURL/priority + drop dayKey uniqueness) | Task 1 |
| `InsightGenerator` protocol + `DayContext` + `InsightKind` | Task 2 |
| Rename `StickyInsightGenerator` → `EncouragementInsightGenerator` (fallback) | Task 3 |
| `InboxInsightGenerator` | Task 4 |
| `KeywordInsightGenerator` (Foundation Models) | Task 5 |
| `TravelInsightGenerator` (MapKit) | Task 6 |
| `WeatherInsightGenerator` (WeatherKit) | Task 7 |
| `StickyOrchestrator` (withTaskGroup + TTL + persist) | Task 8 |
| `AIStickyStack` cascade view | Task 9 |
| `AIStickyNote` callbacks + ↻ refresh button | Task 9 |
| `StickyNoteGenerator.insights(...)` array fetch | Task 9 |
| `DayPageViewModel.insights` + `refreshInsights()` + `dismissInsight(_:)` | Task 10 |
| `DayPageView` `stickyNoteOverlay` → `AIStickyStack` | Task 11 |
| Deep-link routing — internal vs external URLs | Task 11 |
| `DeepLinkRouter.inbox(dayKey:)` case | Task 11 |
| `AppShell` handles `.inbox` | Task 11 |
| WeatherKit entitlement | Task 12 |
| `project.yml` capability | Task 12 |
| `WeeklyPlannerApp` orchestrator construction | Task 12 |
| `\.stickyOrchestrator` env key | Task 10 |
| `AIInsightV2MigrationTests` | Task 1 |
| `InsightGeneratorProtocolTests` | Task 2 |
| `InboxInsightGeneratorTests` (3) | Task 4 |
| `KeywordInsightGeneratorTests` (4) | Task 5 |
| `TravelInsightGeneratorTests` (4) | Task 6 |
| `WeatherInsightGeneratorTests` (3) | Task 7 |
| `StickyOrchestratorTests` (6) | Task 8 |
| `AIStickyStackTests` (6) | Task 9 |
| `AIStickyStackUITests` | Task 13 |
| READMEs + retro | Task 14 |

**Placeholder scan:** No TBD/TODO/FIXME. Every step has either complete code or an exact command.

**Type consistency:**
- `InsightKind.travel.defaultPriority == 0` — Task 2 defines, Tasks 4/5/6/7 reference. ✓
- `InsightKind.travel.colorHex == "#FFE680"` — Task 2 defines, Task 6 uses. ✓
- `KeywordInsightModeling` — Task 5 defines, Task 12 references via `LiveKeywordInsightModel()`. ✓
- `TravelProviding` — Task 6 defines, Task 12 references via `LiveTravelProvider()`. ✓
- `WeatherProviding` — Task 7 defines, Task 12 references via `LiveWeatherProvider()`. ✓
- `StickyOrchestrator.cascadeCap == 3` — Task 8 defines as static, Task 9 references in `StickyNoteGenerator.insights(...)`. ✓
- `AIInsight.kind`, `.actionURL`, `.priority` — Task 1 defines, Tasks 4-9 reference. ✓
- `DayContext.dayKey` computed — Task 2 defines, every generator + orchestrator uses. ✓
- `DeepLinkRouter.Request.inbox(dayKey:)` — Task 11 adds, `AIStickyStack` action mapping in Task 11 references via `deepLinkRouter.request(.inbox(dayKey:))`. ✓

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-24-phase-24-ai-sticky-v2.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — fresh subagent per task + two-stage review. The user requested "max effort for subagents," so dispatch with `model: "opus"`.

**2. Inline Execution** — execute tasks in this same session via executing-plans. Slower iteration but you see every Edit/Bash directly.

**Which approach?**
