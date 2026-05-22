# Phase 24 — AI Sticky v2 (Live & Actionable)

## Goal
Replace the single frozen sticky note per day with a cascade of up to 3 context-aware, actionable insights drawn from four signal sources: travel-time ETA (MapKit), weather (WeatherKit), calendar keyword detection (Foundation Models), and inbox-flagged items. Refresh on day-page open + pull-to-refresh; tap deep-links to the relevant surface; long-press dismisses or refreshes.

## Why this is needed
The current sticky generates one encouraging line per day and never refreshes. The product promise — "AI sticky note that knows what to remind you of" — is unmet. This phase makes the sticky actually intelligent and useful.

## Prerequisites
- Phase 03 (`AIInsight` model + SwiftData), Phase 07 (`AIStickyNote` + folded-tab view), Phase 13 (`IntelligenceService` + `LanguageModelSession` integration), Phase 18 (Foundation Models `@Generable` patterns + Optional gotcha lessons), Phase 19 (deep-link router, location auth), Phase 21 (accessibility patterns).

## Files Created / Modified

```
WeeklyPlanner/Models/AIInsight.swift                                    # MODIFY — +kind, +actionURL, +priority; v2 schema migration
WeeklyPlanner/Intelligence/InsightGenerator.swift                       # NEW — protocol + DayContext
WeeklyPlanner/Intelligence/StickyOrchestrator.swift                     # NEW
WeeklyPlanner/Intelligence/Tasks/TravelInsightGenerator.swift           # NEW
WeeklyPlanner/Intelligence/Tasks/WeatherInsightGenerator.swift          # NEW
WeeklyPlanner/Intelligence/Tasks/KeywordInsightGenerator.swift          # NEW
WeeklyPlanner/Intelligence/Tasks/InboxInsightGenerator.swift            # NEW
WeeklyPlanner/Intelligence/Tasks/EncouragementInsightGenerator.swift    # RENAME from StickyInsightGenerator.swift; fallback only
WeeklyPlanner/Features/DayPage/AIStickyStack.swift                      # NEW — cascade renderer
WeeklyPlanner/Features/DayPage/AIStickyNote.swift                       # MODIFY — accepts onTap/onLongPress callbacks
WeeklyPlanner/Features/DayPage/StickyNoteGenerator.swift                # MODIFY — returns [AIInsight] (cascade), not just first
WeeklyPlanner/Features/DayPage/DayPageView.swift                        # MODIFY — stickyNoteOverlay → AIStickyStack
WeeklyPlanner/Features/DayPage/DayPageViewModel.swift                   # MODIFY — insights array, refreshInsights, dismissInsight
WeeklyPlanner/App/WeeklyPlannerApp.swift                                # MODIFY — orchestrator + WeatherService injection
WeeklyPlanner/Supporting/WeeklyPlanner.entitlements                     # MODIFY — +weatherkit
project.yml                                                             # MODIFY — Capabilities entry
WeeklyPlannerTests/Intelligence/StickyOrchestratorTests.swift           # NEW
WeeklyPlannerTests/Intelligence/TravelInsightGeneratorTests.swift       # NEW
WeeklyPlannerTests/Intelligence/WeatherInsightGeneratorTests.swift      # NEW
WeeklyPlannerTests/Intelligence/KeywordInsightGeneratorTests.swift      # NEW
WeeklyPlannerTests/Intelligence/InboxInsightGeneratorTests.swift        # NEW
WeeklyPlannerTests/DayPage/AIStickyStackTests.swift                     # NEW
WeeklyPlannerTests/Models/AIInsightV2MigrationTests.swift               # NEW
WeeklyPlannerUITests/AIStickyStackUITests.swift                         # NEW
```

## Visual & Interaction Checklist

### `AIStickyStack` (cascade renderer)
- [ ] `ZStack(alignment: .topTrailing)` mounting up to 3 stickies.
- [ ] Top sticky (index 0): full size, tilt from `insight.tiltDegrees`, no offset.
- [ ] Second sticky (index 1): offset `y: 8, x: -4`, tilt `insight.tiltDegrees - 2°`, z-order beneath, shadow slightly darker.
- [ ] Third sticky (index 2): offset `y: 14, x: -8`, tilt `insight.tiltDegrees - 4°`, z-order behind second.
- [ ] When `insights.count < 3`, the peek layers collapse — no empty placeholders.
- [ ] When `insights.isEmpty`, the stack renders `EmptyView()`.

### `AIStickyNote` modifications
- [ ] Accept `onTap: () -> Void` and `onLongPress: () -> Void` callbacks instead of owning its own folded state.
- [ ] Folded state ownership moves to `AIStickyStack` (only the top sticky's `folded` matters).
- [ ] Eyebrow row gains a tiny "↻" SF Symbol button on the trailing edge:
  - [ ] 9×9 `arrow.clockwise` icon, `Color.black.opacity(0.4)`.
  - [ ] Tap → `onRefresh: () -> Void` callback fires `viewModel.refreshInsights()`.
  - [ ] Accessibility: label `"Refresh insights"`, trait `.isButton`.
- [ ] Body tap → `onTap` fires (drives `actionURL` opening at the stack level).
- [ ] Long-press → context menu (see below).

### Context menu
Items adapt to `insight.kind`:
- [ ] `"Show another"` — promotes the next sticky in cascade (if `insights.count > 1`).
- [ ] `"Dismiss this insight"` — sets `dismissed = true` and refreshes.
- [ ] `"Refresh"` — re-runs orchestrator.
- [ ] Kind-specific:
  - [ ] `.travel`: `"Get directions"` — opens Apple Maps via `actionURL`.
  - [ ] `.weather`: `"Open Weather"` — opens system Weather via `weather://`.
  - [ ] `.keyword`: `"Open event"` — opens event sheet via `DeepLinkRouter.request(.event)`.
  - [ ] `.inbox`: `"Open inbox"` — scrolls Day page to inbox block.

### Promote animation (when user explicitly invokes "Show another")
- [ ] Top sticky scales `1.0 → 0.92`, slides down 24pt with `stickyPeel` curve, fades to opacity 0.
- [ ] Next sticky scales `0.96 → 1.0` in parallel, offsets up to top position.
- [ ] Total duration ~0.32s; reduce-motion variant is a 0.18s crossfade.

### Tap action mapping
- [ ] `.travel`: opens `actionURL` via `UIApplication.shared.open(URL)`.
- [ ] `.weather`: opens `weather://` URL (system Weather app).
- [ ] `.keyword`: parses `weeklyplanner://event/<uuid>` → `DeepLinkRouter.request(.event(uuid))`.
- [ ] `.inbox`: parses `weeklyplanner://inbox/<dayKey>` → triggers scroll-to-inbox.
- [ ] `.encouragement`: no action — body tap toggles fold/expand (legacy behavior).

## Logic & Data Checklist

### `AIInsight` v2 schema
- [ ] New fields:
  - `var kind: String` — raw value of `InsightKind`.
  - `var actionURL: String?` — deep link or external URL.
  - `var priority: Int` — cascade sort order.
- [ ] `enum InsightKind: String, Codable { case encouragement, travel, weather, keyword, inbox }`.
- [ ] Uniqueness: at most one non-dismissed insight per `(dayKey, kind)`. Orchestrator enforces.
- [ ] Lightweight `SchemaMigrationPlan` from V1 → V2:
  - Default `kind = .encouragement` for migrated rows.
  - Default `actionURL = nil`.
  - Default `priority = 9`.

### `InsightGenerator` protocol
```swift
@MainActor
protocol InsightGenerator {
    var kind: InsightKind { get }
    func generate(for day: DayContext) async -> AIInsight?
}

struct DayContext: Sendable {
    let weekOffset: Int
    let dayIdx: Int
    let events: [Event]
    let inbox: [InboxSuggestion]
    let now: Date
    let appleIntelligenceEnabled: Bool
}
```

### `TravelInsightGenerator`
- [ ] For each event with `location != nil`, starting `now < event.start < now + 4h`:
  - [ ] Geocode location → `CLLocationCoordinate2D` via `CLGeocoder` (cache 24h per location string).
  - [ ] `MKDirections.calculate(from: currentLocation, to: destination)` — cache 1h per `(eventID, dayHash)`.
  - [ ] `departureBy = event.start - travelTime - 5min buffer`.
  - [ ] If `now < departureBy < now + 60min`, emit `"Leave by HH:mm for <event.title>"`.
- [ ] `actionURL`: `http://maps.apple.com/?daddr=<lat,lon>&dirflg=d`.
- [ ] `priority`: 0.
- [ ] Color: `"#FFE680"` (yellow).
- [ ] Returns `nil` if location auth not `.authorizedWhenInUse`/`.authorizedAlways`, or if any geocode/directions fails.

### `WeatherInsightGenerator`
- [ ] `try await WeatherService.shared.weather(for: currentLocation)`.
- [ ] Inspect `hourlyForecast` for the day window (00:00 → 23:59 of `DayContext`'s day).
- [ ] If any hour overlapping an event has `precipitationChance > 0.4`, emit `"Bring an umbrella — rain at <h>pm"`.
- [ ] Cache 30 minutes per `(roundedLocation, day)`.
- [ ] `actionURL`: `"weather://"`.
- [ ] `priority`: 1.
- [ ] Color: `"#C9F0E0"` (mint).
- [ ] Requires `com.apple.developer.weatherkit` entitlement.

### `KeywordInsightGenerator`
- [ ] Foundation Models `LanguageModelSession.respond(to:generating: KeywordInsightDraft.self)`:
  ```swift
  @Generable
  struct KeywordInsightDraft {
      @Guide(description: "Short handwritten nudge, max 60 chars, no emoji.")
      var text: String
      @Guide(description: "UUID of the related event from the input list, or empty if none.")
      var relatedEventID: String
      @Guide(description: "Confidence 0.0–1.0 that this nudge is useful.")
      var confidence: Double
  }
  ```
- [ ] Prompt summarizes day's events + asks for at most one notable nudge (birthday, anniversary, deadline, named person). Stays ≤ 60 chars. Non-optional `relatedEventID` with empty-string sentinel (per Phase 18 deviation).
- [ ] If `confidence < 0.6`, drop.
- [ ] `actionURL`: `"weeklyplanner://event/<uuid>"` when `relatedEventID` non-empty.
- [ ] `priority`: 2.
- [ ] Color: `"#FFCCC9"` (pink).
- [ ] Returns `nil` when Apple Intelligence is off or the model returns empty.

### `InboxInsightGenerator`
- [ ] Counts non-dismissed pending `InboxSuggestion` rows for `dayKey`.
- [ ] If `count > 0`, emit `"\(count) inbox suggestion\(count == 1 ? "" : "s") for today"`.
- [ ] `actionURL`: `"weeklyplanner://inbox/<dayKey>"`.
- [ ] `priority`: 3.
- [ ] Color: `"#E0DFFF"` (lavender — add to `PaperTheme.stickyColors`).
- [ ] No AI dependency; runs synchronously.

### `EncouragementInsightGenerator` (fallback)
- [ ] Renamed from existing `StickyInsightGenerator`.
- [ ] Same logic as today.
- [ ] Runs only when the orchestrator's primary cascade returns 0 results.
- [ ] `priority`: 9.

### `StickyOrchestrator`
- [ ] `@MainActor final class`.
- [ ] Runs the four primary generators in `withTaskGroup`.
- [ ] Awaits results, drops `nil`, sorts by `priority` ascending, caps at 3.
- [ ] If primary cascade returns 0, runs `EncouragementInsightGenerator` as a single-item fallback.
- [ ] `persist(_ insights:, into: ModelContext, day: DayContext)`:
  - [ ] For each insight, delete existing rows where `dayKey == day.dayKey && kind == insight.kind && !dismissed`.
  - [ ] Insert the new insight.
  - [ ] `try? context.save()`.
- [ ] `TTLCache<String, [AIInsight]>` with 5-min TTL.
- [ ] `cacheKey = "\(weekOffset):\(dayIdx):\(eventsHash)"`. `eventsHash` = stable hash of sorted `(event.id, event.start)` tuples.

### `DayPageViewModel`
- [ ] New: `var insights: [AIInsight] = []`.
- [ ] `refresh()` now calls `orchestrator.run(for: dayContext, into: modelContext)` after the existing event/inbox/task fetch, then re-fetches insights from SwiftData (filtered + sorted by priority, cap 3).
- [ ] New: `func refreshInsights() async` — direct re-trigger from the "↻" button (bypasses TTL cache).
- [ ] New: `func dismissInsight(_ insight: AIInsight) async` — sets `dismissed = true` + save + refresh.

### Cadence
- [ ] `DayPageViewModel.refresh()` runs the orchestrator on every refresh call.
- [ ] Cached results within 5 min skip the generator group; uncached runs do the full async work (~1–3s total — concurrent generators).
- [ ] Pull-to-refresh and "↻" both invalidate the cache for the current day.

### Deep-link routing
- [ ] `DeepLinkRouter` (Phase 19) gains a new case: `case inbox(dayKey: String)`.
- [ ] `AppShell` listens for `.inbox` and scrolls the Day page's inbox section into view.
- [ ] External URLs (`weather://`, `http://maps.apple.com/...`) open via `UIApplication.shared.open`.

### Entitlement + capability
- [ ] Add to `WeeklyPlanner/Supporting/WeeklyPlanner.entitlements`:
  ```xml
  <key>com.apple.developer.weatherkit</key>
  <true/>
  ```
- [ ] Apple Developer Portal: enable WeatherKit capability on the `com.weeklyplanner.WeeklyPlanner` App ID. Document the portal step in the phase-24 RUNBOOK section.
- [ ] `project.yml`: add `weatherkit` to the `entitlements` block so XcodeGen regenerates correctly.
- [ ] `Info.plist`: `NSLocationWhenInUseUsageDescription` already declared (Phase 19); reused for `MKDirections`.

## Tests (TDD)

Per-generator tests (all using fakes for MapKit / WeatherKit / IntelligenceService):

`TravelInsightGeneratorTests`
- [ ] `testEmitsForUpcomingEventWithLocation`.
- [ ] `testNilWhenLocationAuthDenied`.
- [ ] `testNilWhenEventBeyond4Hours`.
- [ ] `testRespectsDepartureThreshold`.

`WeatherInsightGeneratorTests`
- [ ] `testEmitsUmbrellaWhenPrecipChanceHigh`.
- [ ] `testNilWhenNoRainInWindow`.
- [ ] `testCachedFor30Minutes`.

`KeywordInsightGeneratorTests`
- [ ] `testEmitsForBirthdayKeyword`.
- [ ] `testDropsLowConfidence`.
- [ ] `testNilWhenAppleIntelligenceOff`.
- [ ] `testGenerableEmptyStringSentinelHonored`.

`InboxInsightGeneratorTests`
- [ ] `testEmitsCountWhenPending`.
- [ ] `testNilWhenZeroPending`.
- [ ] `testSingularPluralAgreement`.

`StickyOrchestratorTests`
- [ ] `testCascadeOrder_travelBeforeWeatherBeforeKeywordBeforeInbox`.
- [ ] `testCapAt3`.
- [ ] `testFallbackToEncouragementWhenPrimaryEmpty`.
- [ ] `testTTLCacheSkipsSecondCallWithin5Minutes`.
- [ ] `testDismissedInsightExcluded`.
- [ ] `testPersistReplacesByDayKeyAndKind`.

`AIStickyStackTests`
- [ ] `testZeroInsightsRendersEmpty`.
- [ ] `testOneInsightRendersNoPeek`.
- [ ] `testTwoInsightsRendersOnePeek`.
- [ ] `testThreeInsightsRendersTwoPeeks`.
- [ ] `testShowAnother_promotesNextSticky` (driven by context-menu action, NOT body tap).
- [ ] `testShowAnother_fromLast_wrapsToFirst`.
- [ ] `testBodyTap_invokesActionURL_doesNotPromote`.

`AIInsightV2MigrationTests`
- [ ] `testMigratedV1Row_defaultsKindToEncouragement`.
- [ ] `testMigratedV1Row_actionURLNil_priority9`.

`AIStickyStackUITests`
- [ ] `testTapTravelSticky_attemptsToOpenMaps` (URL handler stubbed).

## Acceptance Criteria
- An event with a location, starting within 4 hours, triggers a travel sticky within one refresh cycle.
- Rainy hours overlap an event → weather sticky appears.
- A day with the title "Sara's birthday" → keyword sticky surfaces a nudge referencing Sara.
- A day with pending inbox suggestions → inbox sticky appears with the count.
- Up to 3 stickies render in the cascade; context-menu "Show another" promotes the next sticky; "Show another" from the last sticky wraps back to the first. Body tap opens the `actionURL`, never promotes.
- Pull-to-refresh and "↻" both trigger orchestrator re-runs.
- Long-press → context menu with the right actions per `kind`.
- All `XCUIAccessibilityAudit` UI tests still green; rotor "Insights" works in VoiceOver.

## Out of Scope
- Push-notification-driven insight refresh.
- User-defined custom insight rules.
- Cross-day insights ("you have 4 birthdays this week").
- Background-task scheduled regeneration.

## Risks & Notes
- **WeatherKit entitlement provisioning.** The capability must be enabled on the App ID in the Apple Developer portal before Xcode can sign builds with the entitlement. Mitigation: unit tests use `StubWeatherProvider`; only release builds + on-device verification need the real entitlement. Document the portal step in a `RUNBOOK.md` section of this doc.
- **`MKDirections` request quota.** Apple throttles ~50 reqs/min/device. Cache geocodes + directions per `(eventID, dayHash)` for 1 hour.
- **Foundation Models `@Generable` Optional gotcha.** Keep `relatedEventID: String` non-optional with empty-string sentinel (per Phase 18 retrospective).
- **SwiftData v1 → v2 migration.** Use lightweight migration with default field values. Existing `AIInsight` rows from Phase 13b stay valid as `.encouragement` priority 9.
- **Cascade gesture conflicts.** Tap-to-promote on the top sticky and body-tap-to-open-action both consume the tap. Resolution: tap = action; promote moves to the explicit "↻" or context-menu "Show another". This is a deliberate revision from the brainstorm where tap-to-cycle was considered ambiguous.
- **Concurrent generator failures.** Each generator must `do/catch` internally and return `nil` on error (per Phase 18 per-iter try/catch deviation). One slow/failed generator must not block the others — `withTaskGroup` honors per-task isolation, but the timeout budget (~3s total) is enforced by a `Task.timeout(_:)` wrapper.
- **`theme.ink2` (not `inkMuted`)** — per Phase 19 deviation.
