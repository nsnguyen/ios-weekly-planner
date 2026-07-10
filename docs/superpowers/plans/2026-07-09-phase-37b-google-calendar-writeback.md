# Phase 37b — Google Calendar Write-Back Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Push create/edit/delete of single (non-recurring) planner events to the connected Google primary calendar immediately, with last-write-wins conflict handling.

**Architecture:** A new `GoogleCalendarWriteBackEventStore` decorator sits **outside** `EventKitMirroringEventStore` so a successful push can flip `source` to `.googleCalendar` before EventKit mirroring runs (reusing the 37a loop-prevention skip). `GoogleCalendarClient` gains create/update/get/cancel; `GCalSyncEngine` wraps import/purge mutations in a `@TaskLocal` suppress flag so write-back does not echo or cancel-on-disconnect.

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest, Google Calendar API v3. Build/test via `xcodegen` + `xcodebuild`, iPhone 17 Pro simulator.

**Spec:** `docs/superpowers/specs/2026-07-09-phase-37b-google-calendar-writeback-design.md`

---

## Pre-flight

```bash
git checkout -b phase-37b-gcal-writeback
```

New files under existing globs (`WeeklyPlanner/Stores/GoogleCalendar/`, `WeeklyPlannerTests/GoogleCalendar/`) — run `xcodegen generate` after adding files, before that task’s build/test.

**Build/test:**
```bash
xcodegen generate   # after adding/removing files
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/<Class> CODE_SIGNING_ALLOWED=NO
```

**Commits:** use `git commit -F - <<'EOF'` (or Write a msg file + `git commit -F file`). Never `git commit -m "$(cat <<EOF)"` — `cat` may inject ANSI/line numbers.

---

## File Structure

| File | New/Mod | Responsibility |
|------|---------|----------------|
| `Models/Event.swift` | Mod | `googleEtag: String? = nil`; init + `occurrenceCopy` |
| `Stores/EventStore.swift` | Mod | Copy `googleEtag` on upsert; preserve `event.updatedAt` (don’t force `.init()`) |
| `Stores/GoogleCalendar/GCalMapper.swift` | Mod | Set etag/`updatedAt` on import; `writeBody(from:)` for POST/PATCH |
| `Stores/GoogleCalendar/GCalEvent.swift` | Mod | `GCalEventWriteBody` Encodable; keep `GCalEvent` Decodable |
| `Stores/GoogleCalendar/GoogleCalendarClient.swift` | Mod | `getEvent` / `createEvent` / `updateEvent` / `cancelEvent`; 412 error |
| `Stores/GoogleCalendar/GCalWriteBackContext.swift` | New | `@TaskLocal suppressWriteBack` |
| `Stores/GoogleCalendar/GCalSyncEngine.swift` | Mod | Wrap apply + purge in suppress |
| `Stores/GoogleCalendar/GoogleCalendarWriteBackEventStore.swift` | New | Write-back decorator |
| `App/WeeklyPlannerApp.swift` | Mod | Stack: write-back → EventKit → SwiftData |
| `docs/phases/phase-37-google-calendar-sync.md` | Mod | Mark 37b in progress / shipped notes |
| `WeeklyPlannerTests/GoogleCalendar/*` | New/Mod | Client write, mapper write, write-back, fake client |

---

### Task 1: `Event.googleEtag` + store upsert fidelity

**Files:**
- Modify: `WeeklyPlanner/Models/Event.swift`
- Modify: `WeeklyPlanner/Stores/EventStore.swift`
- Modify: `WeeklyPlannerTests/GoogleCalendar/GCalModelMigrationTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `GCalModelMigrationTests.swift`:

```swift
func testEventHasNilGoogleEtagByDefault() {
    let e = Event(title: "x", start: .now, end: .now, category: .personal)
    XCTAssertNil(e.googleEtag)
}

func testEventStoresGoogleEtag() {
    let e = Event(title: "x", start: .now, end: .now, category: .personal,
                  googleEventID: "gid", googleEtag: "\"etag1\"")
    XCTAssertEqual(e.googleEtag, "\"etag1\"")
}

func testOccurrenceCopyCarriesGoogleEtag() {
    let e = Event(title: "x", start: .now, end: .now.addingTimeInterval(3600),
                  category: .personal, googleEventID: "gid", googleEtag: "\"e\"")
    let copy = e.occurrenceCopy(start: e.start.addingTimeInterval(86400))
    XCTAssertEqual(copy.googleEtag, "\"e\"")
    XCTAssertEqual(copy.googleEventID, "gid")
}
```

- [ ] **Step 2: Run → fails**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/GCalModelMigrationTests CODE_SIGNING_ALLOWED=NO
```

Expected: compile error — `googleEtag` missing.

- [ ] **Step 3: Implement**

In `Event.swift`, after `googleEventID`:
```swift
var googleEtag: String? = nil
```
Add init param `googleEtag: String? = nil` after `googleEventID`, assign `self.googleEtag = googleEtag`. Pass `googleEtag: googleEtag` in `occurrenceCopy`.

In `SwiftDataEventStore.upsert`, when updating `existing`:
```swift
existing.googleEventID = event.googleEventID
existing.googleEtag = event.googleEtag
// ...
existing.updatedAt = event.updatedAt   // was: .init() — preserve caller/LWW timestamp
```

- [ ] **Step 4: Run → passes** (same command as Step 2).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Models/Event.swift WeeklyPlanner/Stores/EventStore.swift \
  WeeklyPlannerTests/GoogleCalendar/GCalModelMigrationTests.swift
git commit -F - <<'EOF'
feat(gcal): Event.googleEtag + preserve updatedAt on upsert

Additive SwiftData field for If-Match / LWW; stop overwriting
updatedAt so remote-win timestamps survive persist.
EOF
```

---

### Task 2: Mapper — import etag + `writeBody(from:)`

**Files:**
- Modify: `WeeklyPlanner/Stores/GoogleCalendar/GCalEvent.swift`
- Modify: `WeeklyPlanner/Stores/GoogleCalendar/GCalMapper.swift`
- Modify: `WeeklyPlannerTests/GoogleCalendar/GCalMapperTests.swift`

- [ ] **Step 1: Add `GCalEventWriteBody` to `GCalEvent.swift`**

```swift
/// Request body for create/update. Only fields we author.
struct GCalEventWriteBody: Encodable, Equatable {
    var summary: String
    var location: String?
    var description: String?
    var start: GCalDateTime
    var end: GCalDateTime
}

// Make GCalDateTime Encodable (add Encodable to the existing struct):
struct GCalDateTime: Codable {
    let date: String?
    let dateTime: String?
}
```

- [ ] **Step 2: Failing mapper tests**

```swift
func testImportCopiesEtagAndUpdatedAt() throws {
    let g = gcal("e1", etag: "\"abc\"", updated: "2026-06-14T12:00:00Z")
    // extend private gcal() helper to accept etag/updated
    let e = try XCTUnwrap(GCalMapper.event(from: g))
    XCTAssertEqual(e.googleEtag, "\"abc\"")
    XCTAssertEqual(e.updatedAt, ISO8601DateFormatter().date(from: "2026-06-14T12:00:00Z"))
}

func testWriteBodyTimedEvent() {
    let start = ISO8601DateFormatter().date(from: "2026-07-09T18:00:00Z")!
    let end = start.addingTimeInterval(3600)
    let e = Event(title: "Sync me", start: start, end: end, location: "Cafe",
                  notes: "hi", category: .personal)
    let body = GCalMapper.writeBody(from: e)
    XCTAssertEqual(body.summary, "Sync me")
    XCTAssertEqual(body.location, "Cafe")
    XCTAssertEqual(body.description, "hi")
    XCTAssertNotNil(body.start.dateTime)
    XCTAssertNil(body.start.date)
    XCTAssertNotNil(body.end.dateTime)
}

func testWriteBodyAllDayUsesDateFields() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = .current
    let day = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 800_000_000))
    let next = cal.date(byAdding: .day, value: 1, to: day)!
    let e = Event(title: "Holiday", start: day, end: next, category: .personal)
    let body = GCalMapper.writeBody(from: e)
    XCTAssertNotNil(body.start.date)
    XCTAssertNil(body.start.dateTime)
    XCTAssertEqual(body.end.date, body.start.date == nil ? nil : {
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: next)
    }())
}
```

Simplify the all-day assertion in the real file: assert `body.start.date != nil`, `body.start.dateTime == nil`, `body.end.date != nil`.

Extend the existing `gcal(...)` helper with `etag: String? = nil, updated: String? = nil` and pass them into `GCalEvent(...)`.

- [ ] **Step 3: Run → fails** (`writeBody` / etag assignment missing).

- [ ] **Step 4: Implement mapper**

Update `event(from:)`:
```swift
let event = Event(id: deterministicID(for: g.id),
                  title: ...,
                  start: start,
                  end: max(end, start),
                  location: g.location,
                  notes: g.description,
                  category: .personal,
                  source: .googleCalendar,
                  googleEventID: g.id,
                  googleEtag: g.etag,
                  updatedAt: parseUpdated(g.updated) ?? Date())
return event
```

Add:
```swift
static func writeBody(from event: Event) -> GCalEventWriteBody {
    if isAllDay(event) {
        return GCalEventWriteBody(
            summary: event.title,
            location: event.location,
            description: event.notes,
            start: GCalDateTime(date: dayString(event.start), dateTime: nil),
            end: GCalDateTime(date: dayString(event.end), dateTime: nil)
        )
    }
    return GCalEventWriteBody(
        summary: event.title,
        location: event.location,
        description: event.notes,
        start: GCalDateTime(date: nil, dateTime: iso.string(from: event.start)),
        end: GCalDateTime(date: nil, dateTime: iso.string(from: event.end))
    )
}

private static func isAllDay(_ event: Event) -> Bool {
    let cal = Calendar.current
    return cal.startOfDay(for: event.start) == event.start
        && cal.startOfDay(for: event.end) == event.end
}

private static func dayString(_ date: Date) -> String {
    day.string(from: date) // reuse existing day DateFormatter
}

private static func parseUpdated(_ s: String?) -> Date? {
    guard let s else { return nil }
    return iso.date(from: s)
}
```

- [ ] **Step 5: Run → passes.**

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/Stores/GoogleCalendar/GCalEvent.swift \
  WeeklyPlanner/Stores/GoogleCalendar/GCalMapper.swift \
  WeeklyPlannerTests/GoogleCalendar/GCalMapperTests.swift
git commit -F - <<'EOF'
feat(gcal): mapper writeBody + import etag/updatedAt

Encode Event → GCalEventWriteBody for POST/PATCH; stamp etag
and remote updated on import for LWW.
EOF
```

---

### Task 3: Client write APIs (`get` / `create` / `update` / `cancel`)

**Files:**
- Modify: `WeeklyPlanner/Stores/GoogleCalendar/GoogleCalendarClient.swift`
- Modify: `WeeklyPlannerTests/GoogleCalendar/GoogleCalendarClientTests.swift`
- Modify: `WeeklyPlannerTests/GoogleCalendar/GCalSyncEngineTests.swift` (Fake client)

- [ ] **Step 1: Extend protocol + errors (will break Fake until Step 4)**

Replace protocol with:
```swift
@MainActor
protocol GoogleCalendarClientProtocol: AnyObject {
    func listEvents(syncToken: String?, timeMin: Date?, timeMax: Date?, pageToken: String?) async throws -> GCalEventsListResponse
    func getEvent(id: String) async throws -> GCalEvent
    func createEvent(_ body: GCalEventWriteBody) async throws -> GCalEvent
    func updateEvent(id: String, body: GCalEventWriteBody, etag: String?) async throws -> GCalEvent
    func cancelEvent(id: String) async throws
}
```

Add to `GoogleCalendarClientError`:
```swift
case preconditionFailed  // 412
case notFound            // 404 on get/cancel
```

- [ ] **Step 2: Failing client tests** (add to `GoogleCalendarClientTests`)

```swift
func testCreateEventPostsJSONAndReturnsId() async throws {
    URLProtocolStub.respond { req in
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.url?.path, "/calendar/v3/calendars/primary/events")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        let body = req.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertTrue(body.contains("Lunch"))
        return .init(status: 200, data: #"""
        {"id":"new1","status":"confirmed","summary":"Lunch",
         "start":{"dateTime":"2026-07-09T12:00:00Z"},
         "end":{"dateTime":"2026-07-09T13:00:00Z"},
         "etag":"\"e1\"","updated":"2026-07-09T12:00:00Z"}
        """#.data(using: .utf8)!)
    }
    let start = ISO8601DateFormatter().date(from: "2026-07-09T12:00:00Z")!
    let body = GCalEventWriteBody(
        summary: "Lunch", location: nil, description: nil,
        start: GCalDateTime(date: nil, dateTime: "2026-07-09T12:00:00Z"),
        end: GCalDateTime(date: nil, dateTime: "2026-07-09T13:00:00Z")
    )
    let created = try await sut.createEvent(body)
    XCTAssertEqual(created.id, "new1")
    XCTAssertEqual(created.etag, "\"e1\"")
}

func testUpdateEventSendsIfMatch() async throws {
    URLProtocolStub.respond { req in
        XCTAssertEqual(req.httpMethod, "PUT")
        XCTAssertEqual(req.value(forHTTPHeaderField: "If-Match"), "\"old\"")
        XCTAssertTrue(req.url?.path.hasSuffix("/events/gid1") == true)
        return .init(status: 200, data: #"""
        {"id":"gid1","status":"confirmed","summary":"Updated",
         "start":{"dateTime":"2026-07-09T12:00:00Z"},
         "end":{"dateTime":"2026-07-09T13:00:00Z"},
         "etag":"\"new\"","updated":"2026-07-09T13:00:00Z"}
        """#.data(using: .utf8)!)
    }
    let body = GCalEventWriteBody(
        summary: "Updated", location: nil, description: nil,
        start: GCalDateTime(date: nil, dateTime: "2026-07-09T12:00:00Z"),
        end: GCalDateTime(date: nil, dateTime: "2026-07-09T13:00:00Z")
    )
    let updated = try await sut.updateEvent(id: "gid1", body: body, etag: "\"old\"")
    XCTAssertEqual(updated.etag, "\"new\"")
}

func testUpdateEvent412ThrowsPreconditionFailed() async throws {
    URLProtocolStub.respond { _ in .init(status: 412, data: Data()) }
    let body = GCalEventWriteBody(
        summary: "X", location: nil, description: nil,
        start: GCalDateTime(date: nil, dateTime: "2026-07-09T12:00:00Z"),
        end: GCalDateTime(date: nil, dateTime: "2026-07-09T13:00:00Z")
    )
    do {
        _ = try await sut.updateEvent(id: "gid1", body: body, etag: "\"stale\"")
        XCTFail("expected throw")
    } catch GoogleCalendarClientError.preconditionFailed { /* ok */ }
}

func testCancelEventPatchesCancelled() async throws {
    URLProtocolStub.respond { req in
        XCTAssertEqual(req.httpMethod, "PATCH")
        let body = req.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertTrue(body.contains("cancelled"))
        return .init(status: 200, data: #"""
        {"id":"gid1","status":"cancelled",
         "start":{"dateTime":"2026-07-09T12:00:00Z"},
         "end":{"dateTime":"2026-07-09T13:00:00Z"}}
        """#.data(using: .utf8)!)
    }
    try await sut.cancelEvent(id: "gid1")
}

func testCancelEvent404IsNotFound() async throws {
    URLProtocolStub.respond { _ in .init(status: 404, data: Data()) }
    do {
        try await sut.cancelEvent(id: "missing")
        XCTFail("expected throw")
    } catch GoogleCalendarClientError.notFound { /* ok */ }
}

func testGetEventFetchesById() async throws {
    URLProtocolStub.respond { req in
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertTrue(req.url?.path.hasSuffix("/events/gid1") == true)
        return .init(status: 200, data: #"""
        {"id":"gid1","status":"confirmed","summary":"Hi",
         "start":{"dateTime":"2026-07-09T12:00:00Z"},
         "end":{"dateTime":"2026-07-09T13:00:00Z"},
         "etag":"\"e\"","updated":"2026-07-09T11:00:00Z"}
        """#.data(using: .utf8)!)
    }
    let g = try await sut.getEvent(id: "gid1")
    XCTAssertEqual(g.summary, "Hi")
}
```

Note: `URLProtocolStub` may not populate `httpBody` from `URLSession` upload — if body asserts flake, assert method/path/headers only and keep JSON decode coverage.

- [ ] **Step 3: Run → fails** (methods missing).

- [ ] **Step 4: Implement client**

Refactor private transport into a shared `send` that accepts method + optional body + optional If-Match:

```swift
func getEvent(id: String) async throws -> GCalEvent {
    let url = baseURL.appending(path: "/calendar/v3/calendars/primary/events/\(id)")
    do {
        return try await send(url: url, method: "GET", body: nil as Data?, ifMatch: nil)
    } catch GoogleCalendarClientError.http(status: 404) {
        throw GoogleCalendarClientError.notFound
    }
}

func createEvent(_ body: GCalEventWriteBody) async throws -> GCalEvent {
    let url = baseURL.appending(path: "/calendar/v3/calendars/primary/events")
    let data = try JSONEncoder().encode(body)
    return try await send(url: url, method: "POST", body: data, ifMatch: nil)
}

func updateEvent(id: String, body: GCalEventWriteBody, etag: String?) async throws -> GCalEvent {
    let url = baseURL.appending(path: "/calendar/v3/calendars/primary/events/\(id)")
    let data = try JSONEncoder().encode(body)
    do {
        return try await send(url: url, method: "PUT", body: data, ifMatch: etag)
    } catch GoogleCalendarClientError.http(status: 412) {
        throw GoogleCalendarClientError.preconditionFailed
    }
}

func cancelEvent(id: String) async throws {
    let url = baseURL.appending(path: "/calendar/v3/calendars/primary/events/\(id)")
    let data = try JSONSerialization.data(withJSONObject: ["status": "cancelled"])
    do {
        let _: GCalEvent = try await send(url: url, method: "PATCH", body: data, ifMatch: nil)
    } catch GoogleCalendarClientError.http(status: 404) {
        throw GoogleCalendarClientError.notFound
    }
}
```

Generalize existing `get` into `send<T: Decodable>(url:method:body:ifMatch:)` — same 401/429/decode handling; set `Content-Type: application/json` when body != nil; set `If-Match` when provided. Keep `listEvents` calling `send` with GET.

Map 410 in `listEvents` to `syncTokenExpired` as today.

- [ ] **Step 5: Update `FakeGoogleCalendarClient`** so existing sync tests compile:

```swift
var created: [GCalEventWriteBody] = []
var updated: [(id: String, body: GCalEventWriteBody, etag: String?)] = []
var cancelledIDs: [String] = []
var getResponses: [String: GCalEvent] = [:]
var createResult: GCalEvent?
var updateResult: GCalEvent?
var throwOnWrite: Error?

func getEvent(id: String) async throws -> GCalEvent {
    if let throwOnWrite { throw throwOnWrite }
    guard let g = getResponses[id] else { throw GoogleCalendarClientError.notFound }
    return g
}
func createEvent(_ body: GCalEventWriteBody) async throws -> GCalEvent {
    if let throwOnWrite { throw throwOnWrite }
    created.append(body)
    return createResult ?? GCalEvent(
        id: "created-\(created.count)", status: "confirmed", summary: body.summary,
        location: body.location, description: body.description,
        start: body.start, end: body.end, etag: "\"new\"",
        updated: ISO8601DateFormatter().string(from: Date())
    )
}
func updateEvent(id: String, body: GCalEventWriteBody, etag: String?) async throws -> GCalEvent {
    if let throwOnWrite { throw throwOnWrite }
    updated.append((id, body, etag))
    return updateResult ?? GCalEvent(
        id: id, status: "confirmed", summary: body.summary,
        location: body.location, description: body.description,
        start: body.start, end: body.end, etag: "\"upd\"",
        updated: ISO8601DateFormatter().string(from: Date())
    )
}
func cancelEvent(id: String) async throws {
    if let throwOnWrite { throw throwOnWrite }
    cancelledIDs.append(id)
}
```

`GCalEvent` needs a memberwise init usable from tests — if Decodable-only synthesis breaks, add an explicit memberwise `init(...)`.

- [ ] **Step 6: Run client + sync-engine tests → pass.**

```bash
xcodegen generate
xcodebuild test ... -only-testing:WeeklyPlannerTests/GoogleCalendarClientTests CODE_SIGNING_ALLOWED=NO
xcodebuild test ... -only-testing:WeeklyPlannerTests/GCalSyncEngineTests CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 7: Commit**

```bash
git commit -F - <<'EOF'
feat(gcal): Calendar client create/update/get/cancel

REST write surface with 401 refresh, 429 backoff, 412 and 404
mapping for write-back and LWW.
EOF
```

---

### Task 4: Echo-suppress context + sync engine wrap

**Files:**
- Create: `WeeklyPlanner/Stores/GoogleCalendar/GCalWriteBackContext.swift`
- Modify: `WeeklyPlanner/Stores/GoogleCalendar/GCalSyncEngine.swift`
- Test: `WeeklyPlannerTests/GoogleCalendar/GCalWriteBackEventStoreTests.swift` (start file; echo test completed in Task 5+)

- [ ] **Step 1: Create context**

```swift
import Foundation

enum GCalWriteBackContext {
    /// When true, `GoogleCalendarWriteBackEventStore` must not call Google.
    /// Set during import apply and disconnect purge.
    @TaskLocal static var suppressWriteBack: Bool = false
}
```

- [ ] **Step 2: Wrap sync engine mutations**

In `apply` and `purge`, wrap store calls:
```swift
try await GCalWriteBackContext.$suppressWriteBack.withValue(true) {
    try await eventStore.delete(id: id)  // or upsert
}
```
For purge’s loop, wrap the whole loop body (or entire purge’s deletes) in one `withValue(true)`.

- [ ] **Step 3: `xcodegen generate` + build.** Commit:

```bash
git add WeeklyPlanner/Stores/GoogleCalendar/GCalWriteBackContext.swift \
  WeeklyPlanner/Stores/GoogleCalendar/GCalSyncEngine.swift
git commit -F - <<'EOF'
feat(gcal): TaskLocal suppress flag for import/purge

Prevents write-back echo on sync upserts and cancel-on-disconnect
during purge.
EOF
```

---

### Task 5: Write-back decorator — create path

**Files:**
- Create: `WeeklyPlanner/Stores/GoogleCalendar/GoogleCalendarWriteBackEventStore.swift`
- Create: `WeeklyPlannerTests/GoogleCalendar/GCalWriteBackEventStoreTests.swift`

- [ ] **Step 1: Failing tests**

```swift
import EventKit
import SwiftData
import XCTest
@testable import WeeklyPlanner

@MainActor
final class GCalWriteBackEventStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var base: SwiftDataEventStore!
    private var gateway: FakeEventKitGateway!
    private var mirrored: EventKitMirroringEventStore!
    private var client: FakeGoogleCalendarClient!
    private var connected = true
    private var sut: GoogleCalendarWriteBackEventStore!
    private var unlinkedIDs: [String] = []

    override func setUp() async throws {
        try await super.setUp()
        container = try SwiftDataStack.inMemoryContainer()
        base = SwiftDataEventStore(context: container.mainContext)
        gateway = FakeEventKitGateway()
        mirrored = EventKitMirroringEventStore(
            base: base, gateway: gateway,
            calendarManager: CategoryCalendarManager(gateway: gateway)
        )
        client = FakeGoogleCalendarClient()
        unlinkedIDs = []
        sut = GoogleCalendarWriteBackEventStore(
            base: mirrored,
            client: client,
            isConnected: { self.connected },
            unlinkEventKitIdentifier: { [weak self] id in self?.unlinkedIDs.append(id) }
        )
    }

    override func tearDown() async throws {
        sut = nil; client = nil; mirrored = nil; gateway = nil; base = nil; container = nil
        try await super.tearDown()
    }

    func testCreateWhileConnectedPostsAndFlipsSource() async throws {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let event = Event(title: "New", start: start, end: start.addingTimeInterval(3600),
                          category: .work, source: .manual)
        try await sut.upsert(event)

        XCTAssertEqual(client.created.count, 1)
        XCTAssertEqual(client.created.first?.summary, "New")
        let stored = try await base.event(id: event.id)
        XCTAssertEqual(stored?.source, .googleCalendar)
        XCTAssertNotNil(stored?.googleEventID)
        XCTAssertNotNil(stored?.googleEtag)
        XCTAssertTrue(gateway.savedEvents.isEmpty, "must skip EventKit after flip")
    }

    func testCreateWhileDisconnectedSkipsGoogle() async throws {
        connected = false
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let event = Event(title: "Local", start: start, end: start.addingTimeInterval(3600),
                          category: .personal, source: .manual)
        try await sut.upsert(event)
        XCTAssertTrue(client.created.isEmpty)
        XCTAssertEqual(try await base.event(id: event.id)?.source, .manual)
        XCTAssertFalse(gateway.savedEvents.isEmpty)
    }

    func testRecurringCreateDoesNotPush() async throws {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let event = Event(title: "Weekly", start: start, end: start.addingTimeInterval(3600),
                          category: .personal, source: .manual,
                          recurrence: Recurrence(frequency: .weekly, interval: 1, end: .never))
        try await sut.upsert(event)
        XCTAssertTrue(client.created.isEmpty)
    }
}
```

- [ ] **Step 2: Run → fails** (type missing). `xcodegen generate` first.

- [ ] **Step 3: Minimal decorator — create + passthrough**

```swift
import Foundation
import os

private let writeLog = Logger(subsystem: "com.weeklyplanner.WeeklyPlanner", category: "GCalWriteBack")

@MainActor
final class GoogleCalendarWriteBackEventStore: EventStoring {
    private let base: any EventStoring
    private let client: any GoogleCalendarClientProtocol
    private let isConnected: () -> Bool
    private let unlinkEventKitIdentifier: (String) -> Void

    init(base: any EventStoring,
         client: any GoogleCalendarClientProtocol,
         isConnected: @escaping () -> Bool,
         unlinkEventKitIdentifier: @escaping (String) -> Void = { _ in })
    {
        self.base = base
        self.client = client
        self.isConnected = isConnected
        self.unlinkEventKitIdentifier = unlinkEventKitIdentifier
    }

    func events(forWeekOffset offset: Int, today: Date) async throws -> [Event] {
        try await base.events(forWeekOffset: offset, today: today)
    }
    func event(id: UUID) async throws -> Event? { try await base.event(id: id) }
    func events(matching query: EventQuery) async throws -> [Event] {
        try await base.events(matching: query)
    }
    func events(source: EventSource) async throws -> [Event] {
        try await base.events(source: source)
    }
    func deleteOccurrence(eventID: UUID, occurrenceStart: Date) async throws {
        try await base.deleteOccurrence(eventID: eventID, occurrenceStart: occurrenceStart)
    }

    func upsert(_ event: Event) async throws {
        var event = event
        if shouldWriteBack(event) {
            do {
                if event.googleEventID == nil {
                    let remote = try await client.createEvent(GCalMapper.writeBody(from: event))
                    applyRemoteIdentity(&event, remote: remote)
                }
                // update path added in Task 6
            } catch {
                writeLog.error("GCal write-back upsert failed: \(String(describing: error), privacy: .public)")
                NotificationCenter.default.post(name: .googleCalendarWriteBackDidFail, object: error.localizedDescription)
                // fall through — persist local without Google identity
            }
        }
        try await base.upsert(event)
    }

    func delete(id: UUID) async throws {
        // cancel path in Task 7 — for now passthrough
        try await base.delete(id: id)
    }

    private func shouldWriteBack(_ event: Event) -> Bool {
        guard isConnected() else { return false }
        guard !GCalWriteBackContext.suppressWriteBack else { return false }
        guard event.recurrence == nil else { return false }
        return true
    }

    private func applyRemoteIdentity(_ event: inout Event, remote: GCalEvent) {
        if let ek = event.eventKitIdentifier {
            unlinkEventKitIdentifier(ek)
            event.eventKitIdentifier = nil
        }
        event.googleEventID = remote.id
        event.googleEtag = remote.etag
        event.source = .googleCalendar
        if let updated = remote.updated.flatMap({ ISO8601DateFormatter().date(from: $0) }) {
            event.updatedAt = updated
        }
    }
}

extension Notification.Name {
    static let googleCalendarWriteBackDidFail =
        Notification.Name("WeeklyPlanner.GoogleCalendar.writeBackDidFail")
}
```

Fix `Event` mutability: `Event` is a class (`@Model`), so use `event` as reference — no `inout` needed:

```swift
func upsert(_ event: Event) async throws {
    if shouldWriteBack(event) {
        do {
            if event.googleEventID == nil {
                let remote = try await client.createEvent(GCalMapper.writeBody(from: event))
                applyRemoteIdentity(event, remote: remote)
            }
        } catch { ... }
    }
    try await base.upsert(event)
}

private func applyRemoteIdentity(_ event: Event, remote: GCalEvent) { ... }
```

- [ ] **Step 4: Run create tests → pass.**

- [ ] **Step 5: Commit**

```bash
git commit -F - <<'EOF'
feat(gcal): write-back decorator create path

POST on upsert when connected and non-recurring; flip to
.googleCalendar and skip EventKit mirror.
EOF
```

---

### Task 6: Write-back — update + LWW + 412 retry

**Files:**
- Modify: `GoogleCalendarWriteBackEventStore.swift`
- Modify: `GCalWriteBackEventStoreTests.swift`

- [ ] **Step 1: Failing tests**

```swift
func testUpdateLocalNewerPushes() async throws {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let event = Event(title: "Old", start: start, end: start.addingTimeInterval(3600),
                      category: .personal, source: .googleCalendar,
                      googleEventID: "gid1", googleEtag: "\"e0\"",
                      updatedAt: Date(timeIntervalSince1970: 2_000_000_000))
    client.getResponses["gid1"] = GCalEvent(
        id: "gid1", status: "confirmed", summary: "Old",
        location: nil, description: nil,
        start: GCalDateTime(date: nil, dateTime: "2026-07-09T12:00:00Z"),
        end: GCalDateTime(date: nil, dateTime: "2026-07-09T13:00:00Z"),
        etag: "\"e0\"",
        updated: "2020-01-01T00:00:00Z" // remote older
    )
    event.title = "New title"
    event.updatedAt = Date(timeIntervalSince1970: 2_100_000_000)
    try await sut.upsert(event)
    XCTAssertEqual(client.updated.count, 1)
    XCTAssertEqual(client.updated.first?.body.summary, "New title")
}

func testUpdateRemoteNewerAppliesRemoteSkipsPush() async throws {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let event = Event(title: "Local", start: start, end: start.addingTimeInterval(3600),
                      category: .personal, source: .googleCalendar,
                      googleEventID: "gid1", googleEtag: "\"e0\"",
                      updatedAt: Date(timeIntervalSince1970: 1_000_000_000))
    client.getResponses["gid1"] = GCalEvent(
        id: "gid1", status: "confirmed", summary: "Remote wins",
        location: nil, description: nil,
        start: GCalDateTime(date: nil, dateTime: "2026-07-09T15:00:00Z"),
        end: GCalDateTime(date: nil, dateTime: "2026-07-09T16:00:00Z"),
        etag: "\"e9\"",
        updated: "2026-07-09T20:00:00Z"
    )
    try await sut.upsert(event)
    XCTAssertTrue(client.updated.isEmpty)
    let stored = try await base.event(id: event.id)
    XCTAssertEqual(stored?.title, "Remote wins")
    XCTAssertEqual(stored?.googleEtag, "\"e9\"")
}

func testUpdate412RetriesOnce() async throws {
    // Configure fake: first update throws preconditionFailed, get returns newer remote,
    // second path should apply remote (remote wins after re-fetch) OR push if local still newer.
    // Simplest script: throwOnWrite = preconditionFailed once via a counter.
}
```

Implement 412 test with a small `FakeGoogleCalendarClient` enhancement:
```swift
var updateBehavior: [Result<GCalEvent, Error>] = []
// in updateEvent: if !updateBehavior.isEmpty { return try updateBehavior.removeFirst().get() }
```

Script: first `.failure(preconditionFailed)`, getResponses has remote older than local, second update `.success(...)`. Assert `updated` attempted twice OR get+one successful update after refresh.

- [ ] **Step 2: Run → fails.**

- [ ] **Step 3: Implement update branch in `upsert`**

```swift
if let gid = event.googleEventID {
    try await pushUpdate(event, googleEventID: gid)
} else {
    let remote = try await client.createEvent(GCalMapper.writeBody(from: event))
    applyRemoteIdentity(event, remote: remote)
}
```

```swift
private func pushUpdate(_ event: Event, googleEventID: String, allowRetry: Bool = true) async throws {
    let remote = try await client.getEvent(id: googleEventID)
    let remoteUpdated = remote.updated.flatMap { ISO8601DateFormatter().date(from: $0) } ?? .distantPast
    if remoteUpdated > event.updatedAt {
        applyMappedRemote(event, remote: remote)
        return
    }
    do {
        let saved = try await client.updateEvent(
            id: googleEventID,
            body: GCalMapper.writeBody(from: event),
            etag: event.googleEtag ?? remote.etag
        )
        event.googleEtag = saved.etag
        if let u = saved.updated.flatMap({ ISO8601DateFormatter().date(from: $0) }) {
            event.updatedAt = u
        }
    } catch GoogleCalendarClientError.preconditionFailed where allowRetry {
        let fresh = try await client.getEvent(id: googleEventID)
        let freshUpdated = fresh.updated.flatMap { ISO8601DateFormatter().date(from: $0) } ?? .distantPast
        if freshUpdated > event.updatedAt {
            applyMappedRemote(event, remote: fresh)
            return
        }
        try await pushUpdate(event, googleEventID: googleEventID, allowRetry: false)
    }
}

private func applyMappedRemote(_ event: Event, remote: GCalEvent) {
    guard let mapped = GCalMapper.event(from: remote) else { return }
    event.title = mapped.title
    event.start = mapped.start
    event.end = mapped.end
    event.location = mapped.location
    event.notes = mapped.notes
    event.googleEtag = mapped.googleEtag
    event.googleEventID = mapped.googleEventID
    event.source = .googleCalendar
    event.updatedAt = mapped.updatedAt
}
```

Keep create/update failures in the outer `do/catch` so local persist still happens.

- [ ] **Step 4: Run → pass.**

- [ ] **Step 5: Commit**

```bash
git commit -F - <<'EOF'
feat(gcal): write-back update with last-write-wins

GET+compare on edit; push when local newer; apply remote when
remote newer; one 412 retry.
EOF
```

---

### Task 7: Write-back — delete cancels on Google

**Files:**
- Modify: `GoogleCalendarWriteBackEventStore.swift`
- Modify: `GCalWriteBackEventStoreTests.swift`

- [ ] **Step 1: Failing tests**

```swift
func testDeleteCancelsRemoteThenRemovesLocal() async throws {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let event = Event(title: "Bye", start: start, end: start.addingTimeInterval(3600),
                      category: .personal, source: .googleCalendar,
                      googleEventID: "gid-del")
    try await base.upsert(event)
    try await sut.delete(id: event.id)
    XCTAssertEqual(client.cancelledIDs, ["gid-del"])
    XCTAssertNil(try await base.event(id: event.id))
}

func testDeleteNotFoundStillDeletesLocal() async throws {
    client.throwOnWrite = GoogleCalendarClientError.notFound
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let event = Event(title: "Gone", start: start, end: start.addingTimeInterval(3600),
                      category: .personal, source: .googleCalendar,
                      googleEventID: "missing")
    try await base.upsert(event)
    client.throwOnWrite = GoogleCalendarClientError.notFound
    try await sut.delete(id: event.id)
    XCTAssertNil(try await base.event(id: event.id))
}

func testPurgeDoesNotCancelRemote() async throws {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let event = Event(title: "Keep in Google", start: start, end: start.addingTimeInterval(3600),
                      category: .personal, source: .googleCalendar,
                      googleEventID: "gid-keep")
    try await base.upsert(event)
    try await GCalWriteBackContext.$suppressWriteBack.withValue(true) {
        try await sut.delete(id: event.id)
    }
    XCTAssertTrue(client.cancelledIDs.isEmpty)
    XCTAssertNil(try await base.event(id: event.id))
}

func testSyncUpsertDoesNotEchoCreate() async throws {
    let g = GCalEvent(
        id: "from-sync", status: "confirmed", summary: "Imported",
        location: nil, description: nil,
        start: GCalDateTime(date: nil, dateTime: "2026-07-09T12:00:00Z"),
        end: GCalDateTime(date: nil, dateTime: "2026-07-09T13:00:00Z"),
        etag: "\"e\"", updated: "2026-07-09T12:00:00Z"
    )
    let event = try XCTUnwrap(GCalMapper.event(from: g))
    try await GCalWriteBackContext.$suppressWriteBack.withValue(true) {
        try await sut.upsert(event)
    }
    XCTAssertTrue(client.created.isEmpty)
    XCTAssertTrue(client.updated.isEmpty)
}
```

- [ ] **Step 2: Implement `delete`**

```swift
func delete(id: UUID) async throws {
    if let event = try await base.event(id: id),
       shouldWriteBack(event),
       let gid = event.googleEventID
    {
        do {
            try await client.cancelEvent(id: gid)
        } catch GoogleCalendarClientError.notFound {
            // already gone — ok
        } catch {
            writeLog.error("GCal cancel failed: \(String(describing: error), privacy: .public)")
            NotificationCenter.default.post(name: .googleCalendarWriteBackDidFail, object: error.localizedDescription)
            // still delete local (user intent)
        }
    }
    try await base.delete(id: id)
}
```

Note: `shouldWriteBack` for delete of google-sourced events: connected + !suppress + non-recurring. Recurring google events shouldn’t exist in 37b import as masters (instances only) — still guard `recurrence == nil`.

- [ ] **Step 3: Run all write-back tests → pass.**

- [ ] **Step 4: Commit**

```bash
git commit -F - <<'EOF'
feat(gcal): cancel on delete + suppress during purge/import

User deletes cancel the Google event; disconnect purge and sync
apply stay local-only.
EOF
```

---

### Task 8: App wiring + EventKit unlink + failure notification (optional UI)

**Files:**
- Modify: `WeeklyPlanner/App/WeeklyPlannerApp.swift`
- Modify: `WeeklyPlanner/Navigation/AppShell.swift` (optional one-liner log/banner)
- Modify: `docs/phases/phase-37-google-calendar-sync.md`

- [ ] **Step 1: Wire stack in `WeeklyPlannerApp.init`**

Replace the bare EventKit assignment with:

```swift
let mirroredStore = EventKitMirroringEventStore(
    base: baseEventStore,
    gateway: eventKitGateway,
    calendarManager: calendarManager
)
let gcalClient = GoogleCalendarClient(auth: googleAuthService, session: URLSession.shared)
let eventStore: any EventStoring = GoogleCalendarWriteBackEventStore(
    base: mirroredStore,
    client: gcalClient,
    isConnected: { [settingsStore] in
        (try? settingsStore.current().googleCalendarConnected) ?? false
    },
    unlinkEventKitIdentifier: { [eventKitGateway] identifier in
        guard eventKitGateway.eventsAuthStatus.isFullAccess else { return }
        let from = Calendar.current.date(byAdding: .day, value: -365, to: Date()) ?? Date()
        let to = Calendar.current.date(byAdding: .day, value: 365, to: Date()) ?? Date()
        let window = eventKitGateway.fetchEvents(from: from, to: to, calendars: nil)
        if let match = window.first(where: { $0.eventIdentifier == identifier }) {
            try? eventKitGateway.remove(match, span: .thisEvent)
        }
    }
)
```

Move `gcalClient` construction above `eventStore` if it was below; remove the duplicate `let gcalClient = ...` later. Pass the same `eventStore` into inbox + `GCalSyncEngine`.

- [ ] **Step 2: Build** → BUILD SUCCEEDED.

- [ ] **Step 3: Optional** — in `AppShell`, `.onReceive` for `.googleCalendarWriteBackDidFail` and set a short `@State` error string if a banner pattern already exists; otherwise logging-only is enough for 37b (spec: non-blocking). Prefer YAGNI: skip UI if no existing banner hook is one line away.

- [ ] **Step 4: Update phase doc status** at top of `docs/phases/phase-37-google-calendar-sync.md`: note 37b implementation in progress / checklist items for write-back.

- [ ] **Step 5: Commit**

```bash
git commit -F - <<'EOF'
feat(gcal): wire write-back store at app launch

Outer decorator wraps EventKit mirror; unlink EK on flip;
sync engine shares the same store with suppress flag.
EOF
```

---

### Task 9: Full suite + phase doc ship note

- [ ] **Step 1: Run Google Calendar test classes**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:WeeklyPlannerTests/GCalModelMigrationTests \
  -only-testing:WeeklyPlannerTests/GCalMapperTests \
  -only-testing:WeeklyPlannerTests/GoogleCalendarClientTests \
  -only-testing:WeeklyPlannerTests/GCalSyncEngineTests \
  -only-testing:WeeklyPlannerTests/GCalWriteBackEventStoreTests \
  -only-testing:WeeklyPlannerTests/GCalMirrorSkipTests \
  -only-testing:WeeklyPlannerTests/ConnectionsCalendarTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all pass.

- [ ] **Step 2: Run broader unit suite** (skip known keychain failures if they still require signing):

```bash
xcodebuild test ... -only-testing:WeeklyPlannerTests CODE_SIGNING_ALLOWED=NO
```

If pre-existing keychain tests fail, note them; do not “fix” unrelated auth tests in this phase.

- [ ] **Step 3: Manual verification checklist** (user / on-device):
  1. Connect Google Calendar.
  2. Create a single event → appears on calendar.google.com.
  3. Edit title/time → updates in Google.
  4. Delete → cancelled/removed in Google.
  5. Create recurring event → stays local only (not in Google).
  6. Edit an event in Google, then edit older copy in app → Google version wins (or re-fetch applies).
  7. Disconnect → local Google rows purged; events remain in Google (not mass-cancelled).

- [ ] **Step 4: Mark phase doc** 37b shipped when manual verification done.

- [ ] **Step 5: Final commit if doc-only changes remain.**

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|------------------|------|
| Immediate push create/edit/delete | 5–7 |
| Last-write-wins | 6 |
| Flip to `.googleCalendar` after push | 5 |
| Cancel on delete | 7 |
| Single events only; recurring skip | 5 |
| Decorator outside EventKit | 5, 8 |
| Echo guard import | 4, 7 |
| No cancel on disconnect purge | 4, 7 |
| Primary calendar only | 3 (URLs) |
| `googleEtag` | 1 |
| Client 401/429/412 | 3 |
| Failed push keeps local | 5 catch |
| No outbox / no multi-cal / no 37c recurrence | out of scope |

No TBD placeholders. Types consistent: `GCalEventWriteBody`, `GoogleCalendarClientError.preconditionFailed` / `.notFound`, `GCalWriteBackContext.suppressWriteBack`.
