# Phase 37a — Google Calendar Import — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Several tasks say "mirror <file>" — read that file for the exact surrounding pattern; the novel code is given here in full.

**Goal:** Import a connected Google account's primary-calendar events into the planner (read-only half of the two-way Phase 37), mirroring the proven Gmail pipeline.

**Architecture:** A dedicated `GoogleCalendarClient` (REST v3 over the `URLSessionProtocol` seam) feeds a `GCalSyncEngine` that incrementally lists events (`singleEvents=true`, `syncToken`), maps each via a pure `GCalMapper` to an `Event(source: .googleCalendar)` with a **deterministic id derived from the Google event id**, and upserts through `EventStoring`. The EventKit mirror decorator **skips** `.googleCalendar`-sourced events so Google↔SwiftData↔iOS-Calendar can't loop. The Settings row connects/disconnects (mirroring Gmail); disconnect purges Google-sourced rows.

**Tech Stack:** Swift, SwiftUI, SwiftData, CryptoKit (deterministic id), XCTest. Build/test via `xcodebuild`, iPhone 17 Pro simulator.

**Spec:** `docs/superpowers/specs/2026-06-14-phase-37a-google-calendar-import-design.md`

---

## Pre-flight: branch

```bash
git checkout -b phase-37a-gcal-import
```

New files are created, so **`xcodegen generate` IS required** before building (XcodeGen is the source of truth — see project memory). Run it after creating files in a task, before that task's build/test step. New files go under existing groups the project already globs (`WeeklyPlanner/Stores/GoogleCalendar/`, `WeeklyPlannerTests/GoogleCalendar/`).

**Build/test commands:**
```bash
xcodegen generate   # only after adding/removing files
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/<Class> CODE_SIGNING_ALLOWED=NO
```
> **Lint:** not a clean gate here (large pre-existing baseline; per-file linting bypasses excludes). Verify only that your *changed* files add no new swiftlint violation. **Keychain caveat:** `GoogleAuthServiceTests`/`TokenKeychainStoreTests` fail under `CODE_SIGNING_ALLOWED=NO` (pre-existing); skip them in full-suite runs.

## File Structure

| File | New/Mod | Responsibility |
|------|---------|----------------|
| `Models/Event.swift` | Mod | add `googleEventID: String? = nil` |
| `Models/UserSettings.swift` | Mod | add `gcalSyncToken: String?`, `googleCalendarAccountEmail: String?` |
| `Auth/GoogleAuth/LiveGoogleAuthService.swift` | Mod | add `calendar.events` scope |
| `Stores/GoogleCalendar/GCalEvent.swift` | New | Decodable DTOs |
| `Stores/GoogleCalendar/GoogleCalendarClient.swift` | New | REST v3 reads (mirror `GmailClient`) |
| `Stores/GoogleCalendar/GCalMapper.swift` | New | pure `GCalEvent → Event` + deterministic id |
| `Stores/GoogleCalendar/GCalDeltaSync.swift` | New | `gcalSyncToken` cursor (mirror `GmailDeltaSync`) |
| `Stores/GoogleCalendar/GCalSyncEngine.swift` | New | orchestrator (mirror `InboxSyncEngine`) |
| `Stores/EventKit/<EventKitMirroringEventStore file>` | Mod | skip mirror for `.googleCalendar` |
| `Features/Settings/ConnectionsViewModel.swift` | Mod | connect/disconnect Google Calendar |
| `Features/Settings/ConnectionsSection.swift` | Mod | enable the row |
| `Stores/Environment+Stores.swift` | Mod | env keys for client + engine |
| `App/WeeklyPlannerApp.swift` | Mod | construct + wire + sync triggers |
| `Stores/Gmail/BackgroundRefreshScheduler.swift` | Mod | calendar refresh task |
| `WeeklyPlannerTests/GoogleCalendar/*` | New | client, mapper, sync-engine, mirror-skip tests |

---

## Task 1: Model fields (Event.googleEventID, UserSettings.gcalSyncToken)

**Files:** `Models/Event.swift`, `Models/UserSettings.swift`, Test: `WeeklyPlannerTests/GoogleCalendar/GCalModelMigrationTests.swift`

- [ ] **Step 1: Failing test** (create the test file)

```swift
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class GCalModelMigrationTests: XCTestCase {
    func testEventHasNilGoogleEventIDByDefault() {
        let e = Event(title: "x", start: .now, end: .now, category: .personal)
        XCTAssertNil(e.googleEventID)
    }

    func testEventStoresGoogleEventID() {
        let e = Event(title: "x", start: .now, end: .now, category: .personal,
                      source: .googleCalendar, googleEventID: "gid_123")
        XCTAssertEqual(e.googleEventID, "gid_123")
        XCTAssertEqual(e.source, .googleCalendar)
    }

    func testUserSettingsGcalSyncTokenDefaultsNil() {
        let s = UserSettings()
        XCTAssertNil(s.gcalSyncToken)
        XCTAssertNil(s.googleCalendarAccountEmail)
    }
}
```

- [ ] **Step 2: Run → fails** (`xcodegen generate` first; missing `googleEventID`/`gcalSyncToken` args).

- [ ] **Step 3: Implement.** In `Event.swift`: add the stored property after `gmailSubject` (line 45) — `var googleEventID: String? = nil` (property-level default is the SwiftData lightweight-migration rule). Add an `init` parameter `googleEventID: String? = nil` after `gmailSubject:` and assign `self.googleEventID = googleEventID`. **Also add `googleEventID: googleEventID` to `occurrenceCopy`** (line ~108) so the transient copy carries it.

In `UserSettings.swift`: add `var gcalSyncToken: String? = nil` and `var googleCalendarAccountEmail: String? = nil` near `gmailLastHistoryId` (line 41); add matching `init` params (defaults `nil`) and assignments.

- [ ] **Step 4: Run → passes.** (`-only-testing:WeeklyPlannerTests/GCalModelMigrationTests`)

- [ ] **Step 5: Commit** `feat(gcal): Event.googleEventID + UserSettings.gcalSyncToken (additive migration)`

---

## Task 2: OAuth Calendar scope

**Files:** `Auth/GoogleAuth/LiveGoogleAuthService.swift`

No unit test (the `scopes` array is `private`; behavior is verified by the live OAuth flow). Keep the change minimal and obvious.

- [ ] **Step 1: Implement.** In `LiveGoogleAuthService.swift`, add to the `scopes` array (currently `gmail.readonly` + `userinfo.email`):
```swift
    "https://www.googleapis.com/auth/calendar.events",
```
Add a comment: `// Phase 37: read+write primary-calendar events (read used in 37a, write in 37b).`

- [ ] **Step 2: Build** → BUILD SUCCEEDED.

- [ ] **Step 3: Commit** `feat(gcal): request calendar.events OAuth scope`

---

## Task 3: GCalEvent DTOs

**Files:** `Stores/GoogleCalendar/GCalEvent.swift`, Test: `WeeklyPlannerTests/GoogleCalendar/GCalEventDecodingTests.swift`

Google Calendar API v3 `events.list` item shape (only the fields we use).

- [ ] **Step 1: Failing test**
```swift
import XCTest
@testable import WeeklyPlanner

final class GCalEventDecodingTests: XCTestCase {
    func testDecodesTimedEvent() throws {
        let json = #"""
        {"items":[{"id":"e1","status":"confirmed","summary":"Lunch",
          "location":"Cafe","description":"notes",
          "start":{"dateTime":"2026-06-14T12:00:00-07:00"},
          "end":{"dateTime":"2026-06-14T13:00:00-07:00"},
          "etag":"\"123\"","updated":"2026-06-14T00:00:00Z"}],
          "nextSyncToken":"TOK"}
        """#.data(using: .utf8)!
        let resp = try JSONDecoder().decode(GCalEventsListResponse.self, from: json)
        XCTAssertEqual(resp.nextSyncToken, "TOK")
        XCTAssertEqual(resp.items.first?.id, "e1")
        XCTAssertEqual(resp.items.first?.summary, "Lunch")
        XCTAssertNotNil(resp.items.first?.start.dateTime)
        XCTAssertNil(resp.items.first?.start.date)
    }

    func testDecodesAllDayAndCancelled() throws {
        let json = #"""
        {"items":[{"id":"e2","status":"cancelled","start":{"date":"2026-06-20"},
          "end":{"date":"2026-06-21"}}],"nextPageToken":"P2"}
        """#.data(using: .utf8)!
        let resp = try JSONDecoder().decode(GCalEventsListResponse.self, from: json)
        XCTAssertEqual(resp.nextPageToken, "P2")
        XCTAssertEqual(resp.items.first?.status, "cancelled")
        XCTAssertEqual(resp.items.first?.start.date, "2026-06-20")
    }
}
```

- [ ] **Step 2: Run → fails** (`xcodegen generate`; no `GCalEventsListResponse`).

- [ ] **Step 3: Implement** `GCalEvent.swift`:
```swift
import Foundation

/// Google Calendar API v3 `events.list` response (only fields we consume).
struct GCalEventsListResponse: Decodable {
    var items: [GCalEvent]
    var nextPageToken: String?
    var nextSyncToken: String?
}

struct GCalEvent: Decodable {
    let id: String
    /// "confirmed" | "tentative" | "cancelled". Cancelled drives a delete.
    let status: String?
    let summary: String?
    let location: String?
    let description: String?
    let start: GCalDateTime
    let end: GCalDateTime
    let etag: String?
    /// RFC3339 last-modified; used by 37b for conflict resolution.
    let updated: String?
}

/// Google sends EITHER `date` (all-day, "yyyy-MM-dd") OR `dateTime` (RFC3339).
struct GCalDateTime: Decodable {
    let date: String?
    let dateTime: String?
}
```
Note: cancelled events may omit `start/end` — make `start`/`end` non-optional only if the API guarantees them with `singleEvents=true`; if a decode test for a cancelled item without start/end fails during the sync-engine task, relax `start`/`end` to optional and handle in the mapper. (For Step 1's cancelled fixture they're present.)

- [ ] **Step 4: Run → passes.**

- [ ] **Step 5: Commit** `feat(gcal): GCalEvent DTOs`

---

## Task 4: GoogleCalendarClient (mirror GmailClient)

**Files:** `Stores/GoogleCalendar/GoogleCalendarClient.swift`, Test: `WeeklyPlannerTests/GoogleCalendar/GoogleCalendarClientTests.swift`

**READ FIRST:** `WeeklyPlanner/Stores/Gmail/GmailClient.swift` (the verbatim template: `init(auth:session:)`, the private `get<T:Decodable>` 401/429 retry loop) and `WeeklyPlannerTests/Gmail/GmailClientTests.swift` (reuse its `URLProtocolStub` and `RecordingAuthService` — same test target, no redefinition).

The only differences from `GmailClient`: base URL `https://www.googleapis.com`, one endpoint, and a `410 → syncTokenExpired` mapping (parallel to Gmail's `404 → historyExpired`).

- [ ] **Step 1: Failing tests** — mirror `GmailClientTests` structure (reuse `URLProtocolStub`/`RecordingAuthService`):
```swift
import XCTest
@testable import WeeklyPlanner

@MainActor
final class GoogleCalendarClientTests: XCTestCase {
    private var fakeAuth: RecordingAuthService!
    private var session: URLSession!
    private var sut: GoogleCalendarClient!

    override func setUp() async throws {
        try await super.setUp()
        fakeAuth = RecordingAuthService(token: "test-token")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        session = URLSession(configuration: config)
        URLProtocolStub.reset()
        sut = GoogleCalendarClient(auth: fakeAuth, session: session)
    }
    override func tearDown() async throws { URLProtocolStub.reset(); try await super.tearDown() }

    func testListEventsSendsSingleEventsAndBearer() async throws {
        URLProtocolStub.respond { req in
            XCTAssertEqual(req.url?.path, "/calendar/v3/calendars/primary/events")
            XCTAssertEqual(req.url?.query?.contains("singleEvents=true"), true)
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            return .init(status: 200, data: #"{"items":[{"id":"e1","start":{"dateTime":"2026-06-14T12:00:00Z"},"end":{"dateTime":"2026-06-14T13:00:00Z"}}],"nextSyncToken":"TOK"}"#.data(using: .utf8)!)
        }
        let page = try await sut.listEvents(syncToken: nil, timeMin: .now, timeMax: .now, pageToken: nil)
        XCTAssertEqual(page.items.first?.id, "e1")
        XCTAssertEqual(page.nextSyncToken, "TOK")
    }

    func testListEventsSendsSyncTokenWhenPresent() async throws {
        URLProtocolStub.respond { req in
            XCTAssertEqual(req.url?.query?.contains("syncToken=PREV"), true)
            return .init(status: 200, data: #"{"items":[],"nextSyncToken":"NEXT"}"#.data(using: .utf8)!)
        }
        _ = try await sut.listEvents(syncToken: "PREV", timeMin: nil, timeMax: nil, pageToken: nil)
    }

    func testRetriesOn429() async throws {
        var calls = 0
        URLProtocolStub.respond { _ in
            calls += 1
            return calls == 1
                ? .init(status: 429, headers: ["Retry-After": "0"], data: Data())
                : .init(status: 200, data: #"{"items":[]}"#.data(using: .utf8)!)
        }
        _ = try await sut.listEvents(syncToken: nil, timeMin: nil, timeMax: nil, pageToken: nil)
        XCTAssertEqual(calls, 2)
    }

    func testRefreshOn401() async throws {
        var calls = 0
        URLProtocolStub.respond { req in
            calls += 1
            if calls == 1 { return .init(status: 401, data: Data()) }
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer refreshed-token")
            return .init(status: 200, data: #"{"items":[]}"#.data(using: .utf8)!)
        }
        fakeAuth.nextRefreshedToken = "refreshed-token"
        _ = try await sut.listEvents(syncToken: nil, timeMin: nil, timeMax: nil, pageToken: nil)
        XCTAssertEqual(calls, 2)
    }

    func test410ThrowsSyncTokenExpired() async throws {
        URLProtocolStub.respond { _ in .init(status: 410, data: Data()) }
        do {
            _ = try await sut.listEvents(syncToken: "old", timeMin: nil, timeMax: nil, pageToken: nil)
            XCTFail("expected throw")
        } catch GoogleCalendarClientError.syncTokenExpired { /* expected */ }
    }
}
```

- [ ] **Step 2: Run → fails** (`xcodegen generate`; no `GoogleCalendarClient`).

- [ ] **Step 3: Implement** `GoogleCalendarClient.swift` — copy `GmailClient`'s `final class` skeleton + the entire private `get<T:Decodable>(url:)` method **verbatim** (the 200/401/429/default loop), changing only the error type to `GoogleCalendarClientError`. Then:
```swift
import Foundation

@MainActor
protocol GoogleCalendarClientProtocol: AnyObject {
    func listEvents(syncToken: String?, timeMin: Date?, timeMax: Date?, pageToken: String?) async throws -> GCalEventsListResponse
}
extension GoogleCalendarClient: GoogleCalendarClientProtocol {}

enum GoogleCalendarClientError: Error, Equatable {
    case syncTokenExpired   // 410 Gone — caller does a full re-sync
    case http(status: Int)
    case decode(String)
}

@MainActor
final class GoogleCalendarClient {
    private let auth: any GoogleAuthService
    private let session: URLSessionProtocol
    private let baseURL = URL(string: "https://www.googleapis.com")!
    private static let maxRetries = 5

    init(auth: any GoogleAuthService, session: URLSessionProtocol) {
        self.auth = auth; self.session = session
    }

    func listEvents(syncToken: String?, timeMin: Date?, timeMax: Date?, pageToken: String?) async throws -> GCalEventsListResponse {
        var c = URLComponents(url: baseURL.appending(path: "/calendar/v3/calendars/primary/events"), resolvingAgainstBaseURL: false)!
        var q = [URLQueryItem(name: "singleEvents", value: "true"),
                 URLQueryItem(name: "maxResults", value: "250")]
        if let syncToken {                       // incremental: timeMin/Max/orderBy are NOT allowed with syncToken
            q.append(URLQueryItem(name: "syncToken", value: syncToken))
        } else {                                 // full: bound the window
            let iso = ISO8601DateFormatter()
            if let timeMin { q.append(URLQueryItem(name: "timeMin", value: iso.string(from: timeMin))) }
            if let timeMax { q.append(URLQueryItem(name: "timeMax", value: iso.string(from: timeMax))) }
        }
        if let pageToken { q.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        c.queryItems = q
        do { return try await get(url: c.url!) }
        catch GoogleCalendarClientError.http(status: 410) { throw GoogleCalendarClientError.syncTokenExpired }
    }

    private func get<T: Decodable>(url: URL) async throws -> T {
        // VERBATIM copy of GmailClient.get(url:) — same 200/401/429/default loop,
        // throwing GoogleCalendarClientError.{decode,http} and
        // GoogleAuthError.reauthenticationRequired on a second 401.
    }
}
```

- [ ] **Step 4: Run → passes** (5 tests).

- [ ] **Step 5: Commit** `feat(gcal): GoogleCalendarClient (REST v3, syncToken, 401/429/410)`

---

## Task 5: GCalMapper (pure GCalEvent → Event, deterministic id)

**Files:** `Stores/GoogleCalendar/GCalMapper.swift`, Test: `WeeklyPlannerTests/GoogleCalendar/GCalMapperTests.swift`

The deterministic id makes re-sync idempotent through `EventStoring.upsert` (which dedups by `id`).

- [ ] **Step 1: Failing tests**
```swift
import XCTest
@testable import WeeklyPlanner

final class GCalMapperTests: XCTestCase {
    private func gcal(_ id: String, status: String? = "confirmed",
                      startDT: String? = nil, endDT: String? = nil,
                      startDate: String? = nil, endDate: String? = nil,
                      summary: String? = "Title", location: String? = nil) -> GCalEvent {
        GCalEvent(id: id, status: status, summary: summary, location: location, description: nil,
                  start: .init(date: startDate, dateTime: startDT),
                  end: .init(date: endDate, dateTime: endDT),
                  etag: nil, updated: nil)
    }

    func testTimedEventMaps() throws {
        let e = try XCTUnwrap(GCalMapper.event(from:
            gcal("e1", startDT: "2026-06-14T12:00:00Z", endDT: "2026-06-14T13:00:00Z", location: "Cafe")))
        XCTAssertEqual(e.title, "Title")
        XCTAssertEqual(e.location, "Cafe")
        XCTAssertEqual(e.source, .googleCalendar)
        XCTAssertEqual(e.googleEventID, "e1")
        XCTAssertEqual(e.end.timeIntervalSince(e.start), 3600, accuracy: 1)
    }

    func testAllDayEventMaps() throws {
        let e = try XCTUnwrap(GCalMapper.event(from:
            gcal("e2", startDate: "2026-06-20", endDate: "2026-06-21")))
        XCTAssertEqual(e.googleEventID, "e2")
        XCTAssertTrue(e.end > e.start)
    }

    func testDeterministicIdIsStableAndDistinct() throws {
        let a1 = GCalMapper.deterministicID(for: "e1")
        let a2 = GCalMapper.deterministicID(for: "e1")
        let b = GCalMapper.deterministicID(for: "e2")
        XCTAssertEqual(a1, a2)        // same google id → same Event.id (idempotent upsert)
        XCTAssertNotEqual(a1, b)
    }

    func testCancelledMapsToNil() {
        XCTAssertNil(GCalMapper.event(from: gcal("e3", status: "cancelled",
                                                 startDate: "2026-06-20", endDate: "2026-06-21")))
    }

    func testMissingTitleGetsPlaceholder() throws {
        let e = try XCTUnwrap(GCalMapper.event(from:
            gcal("e4", startDT: "2026-06-14T12:00:00Z", endDT: "2026-06-14T13:00:00Z", summary: nil)))
        XCTAssertFalse(e.title.isEmpty)
    }
}
```

- [ ] **Step 2: Run → fails** (`xcodegen generate`; no `GCalMapper`).

- [ ] **Step 3: Implement** `GCalMapper.swift`:
```swift
import CryptoKit
import Foundation

/// Pure mapping Google Calendar event → app `Event`. Returns nil for
/// cancelled items (the caller deletes them by deterministic id).
enum GCalMapper {
    /// Stable `Event.id` from a Google event id: SHA-256 → first 16 bytes → UUID.
    /// Same google id ⇒ same Event.id, so `EventStoring.upsert` (dedup-by-id)
    /// updates rather than duplicates on every re-sync.
    static func deterministicID(for googleEventID: String) -> UUID {
        let digest = SHA256.hash(data: Data(googleEventID.utf8))
        var bytes = Array(digest.prefix(16))
        return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],
                           bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
    }

    static func event(from g: GCalEvent) -> Event? {
        guard g.status != "cancelled" else { return nil }
        guard let start = parse(g.start), let end = parse(g.end) else { return nil }
        return Event(id: deterministicID(for: g.id),
                     title: (g.summary?.isEmpty == false ? g.summary! : "(no title)"),
                     start: start,
                     end: max(end, start),
                     location: g.location,
                     notes: g.description,
                     category: .personal,            // a stable default; categorization is out of scope
                     source: .googleCalendar,
                     googleEventID: g.id)
    }

    private static let iso = ISO8601DateFormatter()
    private static let day: DateFormatter = {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static func parse(_ dt: GCalDateTime) -> Date? {
        if let s = dt.dateTime { return iso.date(from: s) }
        if let d = dt.date { return day.date(from: d) }   // all-day → local midnight
        return nil
    }
}
```
(If the `bytes[...]` UUID tuple is unwieldy, `NSUUID` from the 16-byte buffer is an acceptable equivalent — keep it deterministic.)

- [ ] **Step 4: Run → passes.**

- [ ] **Step 5: Commit** `feat(gcal): GCalMapper with deterministic id`

---

## Task 6: GCalDeltaSync (cursor)

**Files:** `Stores/GoogleCalendar/GCalDeltaSync.swift`, Test: `WeeklyPlannerTests/GoogleCalendar/GCalDeltaSyncTests.swift`

**READ FIRST:** `WeeklyPlanner/Stores/Gmail/GmailDeltaSync.swift` — mirror it exactly, swapping `gmailLastHistoryId` → `gcalSyncToken`.

- [ ] **Step 1: Failing test** — construct with an in-memory `SwiftDataSettingsStore` (see `AnnotationLayerTests`/Gmail tests for the in-memory container helper), assert `currentToken()` is nil initially, `save("TOK")` then `currentToken() == "TOK"`.
- [ ] **Step 2: Run → fails.**
- [ ] **Step 3: Implement** mirroring `GmailDeltaSync`: `init(settingsStore:)`, `currentToken() async -> String?` reads `settingsStore.current().gcalSyncToken`, `save(_ token: String?) async` updates it.
- [ ] **Step 4: Run → passes.**
- [ ] **Step 5: Commit** `feat(gcal): GCalDeltaSync cursor`

---

## Task 7: EventKit mirror skip for Google-sourced events

**Files:** the `EventKitMirroringEventStore` file (find with `grep -rl EventKitMirroringEventStore WeeklyPlanner`), Test: `WeeklyPlannerTests/GoogleCalendar/GCalMirrorSkipTests.swift`

**READ FIRST:** the `EventKitMirroringEventStore` file — see how `upsert`/`delete` call the EventKit gateway vs the wrapped base store. Use a fake gateway (or the existing one from EventKit tests) to assert no gateway call for `.googleCalendar`.

- [ ] **Step 1: Failing test** — wrap a base store + a spy gateway; `upsert` a `.googleCalendar` Event; assert the base store got it but the gateway's `save`/`fetch` were **not** called; same for `delete`.
- [ ] **Step 2: Run → fails** (gateway is called).
- [ ] **Step 3: Implement.** At the top of `upsert(_:)`:
```swift
        // Phase 37: Google-sourced events are read-only imports that live only in
        // SwiftData (and Google). Never mirror them to iOS Calendar — that would
        // loop back through EventKitSync. Single source of truth per source.
        guard event.source != .googleCalendar else { try await base.upsert(event); return }
```
For `delete(id:)`: it takes an id, so fetch the event first (the method likely already does, to read `eventKitIdentifier`); if the fetched event's `source == .googleCalendar`, delegate to `base.delete(id:)` and return before any gateway removal. (Google events have `eventKitIdentifier == nil` anyway, but make the skip explicit to match `upsert`.)
- [ ] **Step 4: Run → passes.**
- [ ] **Step 5: Commit** `feat(gcal): skip EventKit mirror for googleCalendar source (loop prevention)`

---

## Task 8: GCalSyncEngine (orchestrator)

**Files:** `Stores/GoogleCalendar/GCalSyncEngine.swift`, Test: `WeeklyPlannerTests/GoogleCalendar/GCalSyncEngineTests.swift`

**READ FIRST:** `WeeklyPlanner/Stores/Gmail/InboxSyncEngine.swift` for the single-flight guard + structure.

- [ ] **Step 1: Failing tests** — with a `FakeGoogleCalendarClient` (returns scripted pages) + an in-memory `SwiftDataEventStore` + `GCalDeltaSync`:
  - `testFullSyncImportsAndStoresToken`: nil token → client called with `syncToken: nil`; mapped events upserted; `nextSyncToken` saved.
  - `testIncrementalSyncSendsStoredToken`: token "T" present → client called with `syncToken: "T"`.
  - `testSyncTokenExpiredFallsBackToFull`: client throws `.syncTokenExpired` on the delta call → engine clears token and re-runs full.
  - `testPaginationFollowsNextPageToken`: page1 has `nextPageToken` → second call sends it; both pages' events imported.
  - `testCancelledItemDeletes`: a prior import then a `cancelled` item for the same google id → the row is gone.
  - `testReSyncUpdatesNotDuplicates`: same google id twice with a changed title → one row, updated title (deterministic id).
  - `testOneBadItemDoesNotKillBatch`: a malformed/unmappable item among good ones → good ones still imported.
  - `testSingleFlightSkipsConcurrentRun`: two overlapping `sync()` calls → client invoked once.
  - `testPurgeRemovesOnlyGoogleSourced`: store has a `.manual` + `.googleCalendar` event → `purge()` removes only the google one and clears the token.

- [ ] **Step 2: Run → fails.**
- [ ] **Step 3: Implement** `GCalSyncEngine` (`@MainActor final class`), mirroring `InboxSyncEngine`'s single-flight (`guard !isRunning; isRunning = true; defer { isRunning = false }`):
```
init(client:, eventStore:, deltaSync:, clock: () -> Date = { .init() })

func sync() async:
  single-flight guard
  token = await deltaSync.currentToken()
  full = (token == nil)
  window: timeMin = clock() - 60d, timeMax = clock() + 120d   // 2mo back / 4mo fwd
  var pageToken: String? = nil
  repeat:
     do:
       page = try client.listEvents(syncToken: token, timeMin: full ? timeMin : nil,
                                     timeMax: full ? timeMax : nil, pageToken: pageToken)
     catch .syncTokenExpired:
       await deltaSync.save(nil); return await sync()   // restart full (token now nil)
     for item in page.items:
        do:
          if item.status == "cancelled" { try await eventStore.delete(id: GCalMapper.deterministicID(for: item.id)) }
          else if let e = GCalMapper.event(from: item) { try await eventStore.upsert(e) }
        catch { continue }                               // per-item isolation
     pageToken = page.nextPageToken
     if let t = page.nextSyncToken { await deltaSync.save(t) }
  while pageToken != nil

func purge() async:   // disconnect cleanup
  for e in (try? await eventStore.events(matching: <source == .googleCalendar query>)) ?? [] {
     try? await eventStore.delete(id: e.id)
  }
  await deltaSync.save(nil)
```
For `purge()`, check `EventQuery` (in `EventStore.swift`) for a source filter; if none exists, add a tiny `eventsBySource(_:)` to `EventStoring` + `SwiftDataEventStore` (FetchDescriptor `#Predicate { $0.sourceRaw == "googleCalendar" }`) and test it.

- [ ] **Step 4: Run → passes.**
- [ ] **Step 5: Commit** `feat(gcal): GCalSyncEngine (incremental, resilient, purge)`

---

## Task 9: Connect / disconnect + enable the Settings row

**Files:** `Features/Settings/ConnectionsViewModel.swift`, `Features/Settings/ConnectionsSection.swift`, Test: `WeeklyPlannerTests/GoogleCalendar/ConnectionsCalendarTests.swift`

**READ FIRST:** `ConnectionsViewModel.swift` (`connectGmail`/`disconnectGmail`, published props, `.gmailDidConnect`) and `ConnectionsSection.swift` (the disabled Google Calendar row).

- [ ] **Step 1: Failing tests** — with a stub auth + in-memory settings store + a spy sync engine:
  - `connectGoogleCalendar` → `googleCalendarConnected == true`, email persisted, posts `.googleCalendarDidConnect`.
  - `disconnectGoogleCalendar` → calls `gcalSyncEngine.purge()`, `googleCalendarConnected == false`, `gcalSyncToken == nil`.
- [ ] **Step 2: Run → fails.**
- [ ] **Step 3: Implement** — mirror the Gmail methods. Add published `isGoogleCalendarConnected` / `googleCalendarAccountEmail`; `connectGoogleCalendar(presenter:)` (OAuth sign-in already grants the calendar scope from Task 2 → persist connected+email → post `.googleCalendarDidConnect`); `disconnectGoogleCalendar()` (await `gcalSyncEngine?.purge()` → persist disconnected + clear token + email). Add `static let googleCalendarDidConnect = Notification.Name("WeeklyPlanner.GoogleCalendar.didConnect")`. In `ConnectionsSection.swift`, change the Google Calendar row from `isEnabled: false` / "Coming soon" to an interactive row bound to the new props (mirror the Gmail row).
- [ ] **Step 4: Run → passes.**
- [ ] **Step 5: Commit** `feat(gcal): connect/disconnect + enable the Settings row`

---

## Task 10: App + environment wiring + background refresh

**Files:** `Stores/Environment+Stores.swift`, `App/WeeklyPlannerApp.swift`, `Stores/Gmail/BackgroundRefreshScheduler.swift`

**READ FIRST:** all three — mirror the Gmail wiring exactly. No new unit tests (composition root); verified by build + the regression suite + manual run.

- [ ] **Step 1: Env keys.** In `Environment+Stores.swift` add (next to `gmailClient`/`inboxSyncEngine`):
```swift
    @Entry var googleCalendarClient: (any GoogleCalendarClientProtocol)? = nil
    @Entry var gcalSyncEngine: GCalSyncEngine? = nil
```
- [ ] **Step 2: App wiring.** In `WeeklyPlannerApp.swift`, construct `GoogleCalendarClient(auth:session:)` and `GCalSyncEngine(client:eventStore:deltaSync:)` alongside the Gmail equivalents, store in `@State`, inject into the environment, and: kick `gcalSyncEngine.sync()` in a `Task` on `.googleCalendarDidConnect` and on launch when `googleCalendarConnected` (mirror the `.gmailDidConnect` trigger).
- [ ] **Step 3: Background task.** In `BackgroundRefreshScheduler.swift`, register/append a `"com.weeklyplanner.WeeklyPlanner.gcalRefresh"` task that runs `gcalSyncEngine.sync()` (mirror the Gmail task; if the scheduler is Gmail-specific, generalize it to take both engines or add a parallel registration).
- [ ] **Step 4: Build → BUILD SUCCEEDED.**
- [ ] **Step 5: Commit** `feat(gcal): wire client + sync engine + background refresh`

---

## Task 11: Full regression + lint + on-device verification

- [ ] **Step 1: Full unit suite** (skip the keychain baseline):
```bash
xcodegen generate
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests \
  -skip-testing:WeeklyPlannerTests/GoogleAuthServiceTests \
  -skip-testing:WeeklyPlannerTests/TokenKeychainStoreTests \
  CODE_SIGNING_ALLOWED=NO
```
Expected: **TEST SUCCEEDED**, 0 failures.

- [ ] **Step 2: swiftlint** — `swiftlint --strict` grepped to the changed/new files; confirm no new violations.

- [ ] **Step 3: Manual on-device verification (user).** Add the `calendar.events` scope to the Google Cloud OAuth consent screen. Connect a real Google account in Settings → Connections → Google Calendar; confirm primary-calendar events import into Day/Week in the right slots; edit one in Google + re-sync → updates (no duplicate); disconnect → Google events vanish, manual events remain. Record actual results; the "unverified app" interstitial may appear (Phase 17).

- [ ] **Step 4: Commit** any fixes from Step 3.

---

## Self-review notes

- **Spec coverage:** scope (T2); client + 401/429/410 (T4); DTO (T3); mapper all-day/timed/cancelled + dedup id (T5); incremental syncToken + 410 fallback + single-flight + per-item isolation + pagination (T8); planner-only/no-loop (T7); disconnect purge (T8 purge + T9); enable row + connect/disconnect (T9); model fields (T1); wiring + BG (T10); tests (T3–T9); live verify (T11). All spec sections map to a task.
- **Type consistency:** `GoogleCalendarClient.listEvents(syncToken:timeMin:timeMax:pageToken:) -> GCalEventsListResponse` (T4) is consumed identically in T8. `GoogleCalendarClientError.syncTokenExpired` (T4) is caught in T8. `GCalMapper.event(from:) -> Event?` and `deterministicID(for:) -> UUID` (T5) are used in T8. `googleEventID`/`gcalSyncToken` (T1) used in T5/T6. `.googleCalendarDidConnect` (T9) observed in T10.
- **Build-green ordering:** T1–T7 are additive/independent; T8 depends on T4–T7; T9–T10 wire it; each task builds + tests green. New files require `xcodegen generate` before their build step.
- **No placeholders:** novel code is complete; "mirror <file>" tasks name the exact template + the precise diffs (the executing subagent reads the template).
