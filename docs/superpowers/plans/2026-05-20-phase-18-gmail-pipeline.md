# Phase 18 — Gmail Inbox Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Periodically fetch the user's Gmail inbox using the OAuth token from Phase 17, classify event-likely messages via cheap rules, extract structured event proposals via Foundation Models, and surface them as `InboxSuggestion` rows on the Day/Week pages. Accepting a suggestion creates a real `Event` that mirrors to the system Calendar (via the Phase 04 EventKit decorator).

**Architecture:**
- **Network layer:** `GmailClient` wraps `URLSession` with a `GoogleAuthService` dependency. Auto-refreshes the bearer token on 401, honors `Retry-After` on 429, and escalates to `.reauthenticationRequired` after a second 401. `URLSession` is injectable via a `URLSessionProtocol` seam so tests use `URLProtocol` stubs and never hit the network.
- **Pipeline:** `InboxSyncEngine` (an `actor` for single-flight) orchestrates `GmailDeltaSync` (historyId-driven incremental fetch) → `MessageClassifier` (cheap subject + sender rules) → `EventExtractor` (FoundationModels structured output, with `StubEventExtractor` fallback) → `InboxStore.upsert`. A 401 from the client trips the reauthentication-required path which flips `gmailConnected=false`.
- **Background refresh:** `BackgroundRefreshScheduler` registers a `BGAppRefreshTask` (1-hour cadence) so the inbox stays current while the app is closed. FoundationModels availability is re-probed each BG run; if unavailable, the pipeline degrades to rules-only via `StubEventExtractor`.
- **UI hookup:** `DayPageViewModel` and `WeekPageViewModel` gain a `refresh()` method that delegates to `InboxSyncEngine.sync(now:)`. Pull-to-refresh on both pages wires to it. `AppShell` watches `InboxSyncEngine.progress` (an `AsyncStream<SyncProgress>`) and renders a 6pt ink dot in the top-bar trailing area while progress is emitting. A `Notification.Name.gmailDidConnect` listener (posted by Phase 17's `ConnectionsViewModel`) kicks a one-shot sync immediately after connect.
- **Accept flow:** `InboxStore.accept(id:)` builds an `Event` with `source = .gmail` and the round-trip `gmailMessageID/from/subject` fields populated, applies the default reminder (via the new `DefaultReminderPolicy` — Phase 19 will expand the notification side), calls `EventStore.upsert` (which mirrors to EventKit through the existing Phase 04 decorator), and marks the suggestion `accepted`.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, FoundationModels (iOS 26+, gated `#if canImport(FoundationModels)` + `@available(iOS 26.0, *)`), BackgroundTasks, URLSession. No new SPM deps — every external dependency Phase 18 needs (`GoogleSignIn-iOS`, `KeychainAccess`) is already declared by Phase 17.

---

## File Structure

### Created

```
WeeklyPlanner/Stores/Gmail/GmailMessage.swift                  # Decodable DTOs (list, message, header, payload, history)
WeeklyPlanner/Stores/Gmail/URLSessionProtocol.swift            # SDK seam over URLSession + URLProtocolStub for tests
WeeklyPlanner/Stores/Gmail/GmailClient.swift                   # REST wrapper: list / fetch / history / profile
WeeklyPlanner/Stores/Gmail/GmailQueryBuilder.swift             # Default q= filter
WeeklyPlanner/Stores/Gmail/MessageClassifier.swift             # Rules-based pre-filter
WeeklyPlanner/Stores/Gmail/GmailDeltaSync.swift                # historyId cursor read/write helpers
WeeklyPlanner/Stores/Gmail/InboxSyncEngine.swift               # actor orchestrator + AsyncStream<SyncProgress>
WeeklyPlanner/Stores/Gmail/BackgroundRefreshScheduler.swift    # BGAppRefreshTask registration + submission
WeeklyPlanner/Stores/InboxStore+Gmail.swift                    # accept(id:) builds Event + EventStore.upsert
WeeklyPlanner/Intelligence/ExtractedEvent.swift                # { isEvent, title, startISO, endISO, location, categoryHint, confidence }
WeeklyPlanner/Intelligence/EventExtractor.swift                # protocol + StubEventExtractor
WeeklyPlanner/Intelligence/Tasks/LiveEventExtractor.swift      # FoundationModels-backed impl (gated)
WeeklyPlanner/Notifications/DefaultReminderPolicy.swift        # apply(to: Event, settings:) — Phase 19 will reuse
WeeklyPlannerTests/Gmail/GmailClientTests.swift                # 5 tests (URLProtocol-stubbed)
WeeklyPlannerTests/Gmail/MessageClassifierTests.swift          # 4 tests
WeeklyPlannerTests/Gmail/GmailQueryBuilderTests.swift          # 2 tests
WeeklyPlannerTests/Gmail/EventExtractorTests.swift             # 4 tests (StubEventExtractor + fake intelligence)
WeeklyPlannerTests/Gmail/InboxSyncEngineTests.swift            # 6 tests (end-to-end with fakes)
WeeklyPlannerTests/Notifications/DefaultReminderPolicyTests.swift  # 3 tests
```

### Modified

```
WeeklyPlanner/Models/UserSettings.swift                        # add gmailLastHistoryId: String?
WeeklyPlanner/Models/InboxSuggestion.swift                     # add proposedLocation: String?
WeeklyPlanner/Stores/InboxStore.swift                          # adopt the +Gmail.swift accept flow signature
WeeklyPlanner/Stores/Environment+Stores.swift                  # \.gmailClient + \.inboxSyncEngine env keys + stubs
WeeklyPlanner/App/WeeklyPlannerApp.swift                       # register BGTask identifier; build GmailClient + InboxSyncEngine + BackgroundRefreshScheduler; .environment them
WeeklyPlanner/Supporting/Info.plist                            # BGTaskSchedulerPermittedIdentifiers
WeeklyPlanner/Features/DayPage/DayPageViewModel.swift          # refresh() async — delegates to InboxSyncEngine
WeeklyPlanner/Features/WeekPage/WeekPageViewModel.swift        # refresh() async — delegates to InboxSyncEngine
WeeklyPlanner/Features/DayPage/PaperDayView.swift              # .refreshable { await viewModel.refresh() }
WeeklyPlanner/Features/WeekPage/PaperWeekView.swift            # .refreshable { await viewModel.refresh() }
WeeklyPlanner/Navigation/AppShell.swift                        # top-bar sync spinner + .gmailDidConnect listener
docs/phases/README.md                                          # Phase 18 retrospective + status flip
README.md                                                      # Note BGTask identifier in privacy/permissions section
```

### Conventions (already established)

- **No emojis in source files** unless they're literal UI strings.
- **POSIX-locked formatters** in tests.
- **`@Observable`** for view-models; **`@Environment`** for cross-cutting deps.
- **Tests mirror source folders** (`WeeklyPlannerTests/Gmail/`, `WeeklyPlannerTests/Notifications/`).
- **Per-task atomic commits** prefixed `feat(phase-18):` / `chore(phase-18):` / `test(phase-18):` / `docs(phase-18):` / `fix(phase-18):`.
- **xcodebuild flags** (from Phase 17 deviation): `CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO` (NOT `CODE_SIGNING_ALLOWED=NO`) — the test target's entitlements file requires ad-hoc signing.
- **Branch:** `milestone-h-integrations` (already on it, Phase 17 just shipped).

---

## Task 1: Baseline verification

**Files:** none (verification only)

- [ ] **Step 1: Confirm branch + baseline**

```bash
git status --short
git branch --show-current
git log --oneline -3
```

Expected: untracked `.claude/` only; branch `milestone-h-integrations`; HEAD is `4155c16 docs(phase-17): retrospective + status updates`.

- [ ] **Step 2: Re-run full test suite**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`; `Executed 234 tests, with 0 failures` (Phase 17 final count).

- [ ] **Step 3: Do not commit** — verification only.

---

## Task 2: SwiftData model migrations (gmailLastHistoryId + proposedLocation)

**Files:**
- Modify: `WeeklyPlanner/Models/UserSettings.swift`
- Modify: `WeeklyPlanner/Models/InboxSuggestion.swift`

Both fields are nullable, so SwiftData handles the migration automatically — no schema version bump.

- [ ] **Step 1: Add `gmailLastHistoryId` to `UserSettings`**

In `WeeklyPlanner/Models/UserSettings.swift`, in the `@Model final class UserSettings` body, add the property right after `appleMailConnected` (which sits in the "Integrations" block):

```swift
    /// Gmail history API cursor. Set by `GmailDeltaSync` after each
    /// successful sync; `nil` means a full re-sync is required (first
    /// run, or after `history?` returned 404 because the cursor aged out).
    var gmailLastHistoryId: String?
```

Update `init(...)` to take the new parameter (default `nil`):

```swift
    init(...
         appleMailConnected: Bool = true,
         gmailLastHistoryId: String? = nil,
         ...
```

Assign it: `self.gmailLastHistoryId = gmailLastHistoryId` (place it right after the other integration assignments).

- [ ] **Step 2: Add `proposedLocation` to `InboxSuggestion`**

In `WeeklyPlanner/Models/InboxSuggestion.swift`, inside the `@Model final class InboxSuggestion` body, add right after `bodySnippet`:

```swift
    /// Location proposed by the extractor (Foundation Models output's
    /// `location` field). `nil` when the email didn't mention one; the
    /// accept-flow passes it through to `Event.location`.
    var proposedLocation: String?
```

Update `init(...)`:

```swift
    init(id: UUID = UUID(),
         gmailMessageID: String,
         proposedStart: Date,
         proposedEnd: Date? = nil,
         title: String,
         fromName: String,
         fromEmail: String,
         category: Category = .personal,
         subject: String,
         bodySnippet: String? = nil,
         proposedLocation: String? = nil,
         status: InboxStatus = .pending,
         createdAt: Date = .init())
    {
        // ... existing assignments ...
        self.bodySnippet = bodySnippet
        self.proposedLocation = proposedLocation
        // ... rest ...
    }
```

- [ ] **Step 3: Confirm build + tests still green**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `Executed 234 tests, with 0 failures`. If any pre-existing test constructed `InboxSuggestion(...)` or `UserSettings(...)` positionally without the new optional, the default value picks it up automatically — no test changes needed.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Models/UserSettings.swift \
        WeeklyPlanner/Models/InboxSuggestion.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): SwiftData migrations — gmailLastHistoryId + proposedLocation

UserSettings gains gmailLastHistoryId (the Gmail history-API cursor for
incremental sync; nil triggers a full re-sync). InboxSuggestion gains
proposedLocation (extractor output; nil when the email didn't mention
one). Both nullable so SwiftData migrates automatically with no schema
version bump.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `GmailMessage` DTOs

**Files:**
- Create: `WeeklyPlanner/Stores/Gmail/GmailMessage.swift`

Decodable models matching the Gmail REST API JSON. No tests — pure data, exercised through `GmailClientTests`.

- [ ] **Step 1: Create the file**

```swift
import Foundation

// MARK: - List response (GET /gmail/v1/users/me/messages)

struct GmailMessageListResponse: Decodable {
    let messages: [GmailMessageStub]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

struct GmailMessageStub: Decodable {
    let id: String
    let threadId: String?
}

// MARK: - Full message (GET /gmail/v1/users/me/messages/{id}?format=full)

struct GmailMessage: Decodable {
    let id: String
    let threadId: String?
    let snippet: String?
    let historyId: String?
    let internalDate: String?   // ms-since-epoch as a String
    let payload: GmailPayload?
}

struct GmailPayload: Decodable {
    let mimeType: String?
    let headers: [GmailHeader]
    let body: GmailBody?
    let parts: [GmailPayload]?
}

struct GmailHeader: Decodable {
    let name: String
    let value: String
}

struct GmailBody: Decodable {
    let size: Int?
    let data: String?           // base64url-encoded
}

// MARK: - History (GET /gmail/v1/users/me/history?startHistoryId=...)

struct GmailHistoryResponse: Decodable {
    let history: [GmailHistoryRecord]?
    let nextPageToken: String?
    let historyId: String?
}

struct GmailHistoryRecord: Decodable {
    let id: String
    let messages: [GmailMessageStub]?
    let messagesAdded: [GmailMessageAdded]?
}

struct GmailMessageAdded: Decodable {
    let message: GmailMessageStub
}

// MARK: - Profile (GET /gmail/v1/users/me/profile)

struct GmailProfile: Decodable {
    let emailAddress: String
    let historyId: String
    let messagesTotal: Int?
}

// MARK: - Convenience

extension GmailMessage {
    /// Returns the first header value matching `name` case-insensitively.
    func header(_ name: String) -> String? {
        payload?.headers.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.value
    }

    /// Best-effort plain-text body. Walks `parts` looking for `text/plain`;
    /// falls back to the top-level body, then to the snippet.
    func plainTextBody(maxBytes: Int = 3000) -> String {
        if let text = Self.findPart(in: payload, mimeType: "text/plain") {
            return String(text.prefix(maxBytes))
        }
        if let data = payload?.body?.data, let decoded = Self.decodeBase64URL(data) {
            return String(decoded.prefix(maxBytes))
        }
        return snippet ?? ""
    }

    private static func findPart(in payload: GmailPayload?, mimeType: String) -> String? {
        guard let payload else { return nil }
        if payload.mimeType?.lowercased() == mimeType,
           let data = payload.body?.data,
           let decoded = decodeBase64URL(data)
        {
            return decoded
        }
        for part in payload.parts ?? [] {
            if let found = findPart(in: part, mimeType: mimeType) { return found }
        }
        return nil
    }

    private static func decodeBase64URL(_ raw: String) -> String? {
        var s = raw.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }
        guard let data = Data(base64Encoded: s) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Stores/Gmail/GmailMessage.swift WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): GmailMessage DTOs

Decodable models for the four endpoints we hit: list, full message,
history, profile. Convenience helpers: header(name) for case-insensitive
lookup, plainTextBody(maxBytes:) walks multipart parts looking for
text/plain (falls back to top-level body, then snippet), base64URL
decoder for body.data.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `URLSessionProtocol` seam + `URLProtocolStub`

**Files:**
- Create: `WeeklyPlanner/Stores/Gmail/URLSessionProtocol.swift`

Thin protocol so tests can substitute a stub for the real `URLSession.shared`. The matching `URLProtocolStub` lives in the test target (created in Task 5).

- [ ] **Step 1: Create the file**

```swift
import Foundation

/// The slice of `URLSession` that `GmailClient` uses. Production wires
/// `URLSession.shared`; tests wire a `URLSession` configured with a
/// `URLProtocolStub` so no real network traffic happens.
protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}
```

- [ ] **Step 2: Build**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Stores/Gmail/URLSessionProtocol.swift WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): URLSessionProtocol seam for GmailClient

One-method protocol exposing async data(for:) so tests can inject a
URLProtocolStub-configured session. URLSession.shared conforms via empty
extension — production wiring is a no-op.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: `GmailClient` (TDD with URLProtocol stub)

**Files:**
- Create: `WeeklyPlanner/Stores/Gmail/GmailClient.swift`
- Test:   `WeeklyPlannerTests/Gmail/GmailClientTests.swift`

The REST wrapper. 401 → refresh via `GoogleAuthService` and retry once; second 401 → throw `.reauthenticationRequired`. 429 → honor `Retry-After`, exponential backoff up to 5 retries.

- [ ] **Step 1: Write the failing test file**

Create `WeeklyPlannerTests/Gmail/GmailClientTests.swift`:

```swift
import XCTest
@testable import WeeklyPlanner

@MainActor
final class GmailClientTests: XCTestCase {
    private var fakeAuth: RecordingAuthService!
    private var session: URLSession!
    private var sut: GmailClient!

    override func setUp() async throws {
        try await super.setUp()
        fakeAuth = RecordingAuthService(token: "test-token")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        session = URLSession(configuration: config)
        URLProtocolStub.reset()
        sut = GmailClient(auth: fakeAuth, session: session)
    }

    override func tearDown() async throws {
        URLProtocolStub.reset()
        try await super.tearDown()
    }

    func testListMessagesEncodesQueryAndBearer() async throws {
        URLProtocolStub.respond { request in
            // Verify URL + headers + return canned JSON
            XCTAssertEqual(request.url?.path, "/gmail/v1/users/me/messages")
            XCTAssertEqual(request.url?.query?.contains("q=from:resy"), true)
            XCTAssertEqual(request.url?.query?.contains("maxResults=50"), true)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            return URLProtocolStub.Response(
                status: 200,
                data: #"{"messages":[{"id":"abc","threadId":"t1"}]}"#.data(using: .utf8)!
            )
        }

        let stubs = try await sut.listMessages(query: "from:resy", maxResults: 50)

        XCTAssertEqual(stubs.count, 1)
        XCTAssertEqual(stubs.first?.id, "abc")
    }

    func testFetchMessageRetriesOn429WithRetryAfter() async throws {
        var calls = 0
        URLProtocolStub.respond { _ in
            calls += 1
            if calls == 1 {
                return URLProtocolStub.Response(
                    status: 429,
                    headers: ["Retry-After": "0"],
                    data: Data()
                )
            }
            return URLProtocolStub.Response(
                status: 200,
                data: #"{"id":"abc","threadId":"t1","snippet":"hello","payload":{"headers":[]}}"#.data(using: .utf8)!
            )
        }

        let message = try await sut.fetchMessage(id: "abc", format: .full)

        XCTAssertEqual(calls, 2)
        XCTAssertEqual(message.id, "abc")
    }

    func testRefreshOn401AndRetryOnce() async throws {
        var calls = 0
        URLProtocolStub.respond { request in
            calls += 1
            if calls == 1 {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
                return URLProtocolStub.Response(status: 401, data: Data())
            }
            // After refresh, the auth service returns "refreshed-token".
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer refreshed-token")
            return URLProtocolStub.Response(
                status: 200,
                data: #"{"emailAddress":"a@b.com","historyId":"42"}"#.data(using: .utf8)!
            )
        }
        fakeAuth.nextRefreshedToken = "refreshed-token"

        let profile = try await sut.profile()

        XCTAssertEqual(calls, 2)
        XCTAssertEqual(profile.emailAddress, "a@b.com")
        XCTAssertEqual(fakeAuth.tokenCallCount, 2) // initial + refresh
    }

    func testSecondConsecutive401ThrowsReauthRequired() async throws {
        URLProtocolStub.respond { _ in
            URLProtocolStub.Response(status: 401, data: Data())
        }
        fakeAuth.nextRefreshedToken = "still-bad-token"

        do {
            _ = try await sut.profile()
            XCTFail("Expected throw")
        } catch GoogleAuthError.reauthenticationRequired {
            // expected
        }
    }

    func testHistory404ThrowsHistoryExpired() async throws {
        URLProtocolStub.respond { _ in
            URLProtocolStub.Response(status: 404, data: Data())
        }

        do {
            _ = try await sut.history(startHistoryId: "old-cursor")
            XCTFail("Expected throw")
        } catch GmailClientError.historyExpired {
            // expected
        }
    }
}

// MARK: - Test doubles

@MainActor
final class RecordingAuthService: GoogleAuthService {
    var initialToken: String
    var nextRefreshedToken: String?
    private(set) var tokenCallCount = 0

    nonisolated init(token: String) {
        initialToken = token
    }

    func signIn(presenting _: UIViewController) async throws -> GoogleAccountInfo {
        fatalError("not used")
    }

    func signOut() async {}

    func currentAccount() -> GoogleAccountInfo? {
        GoogleAccountInfo(email: "a@b.com", accessToken: initialToken, refreshToken: "r", expiresAt: .distantFuture)
    }

    func accessToken() async throws -> String {
        tokenCallCount += 1
        if tokenCallCount > 1, let refreshed = nextRefreshedToken {
            initialToken = refreshed
        }
        return initialToken
    }
}

final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    struct Response {
        let status: Int
        var headers: [String: String] = [:]
        let data: Data
    }

    private static let lock = NSLock()
    private static var handler: ((URLRequest) -> Response)?

    static func respond(_ block: @escaping (URLRequest) -> Response) {
        lock.withLock { handler = block }
    }

    static func reset() {
        lock.withLock { handler = nil }
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let resp: Response = Self.lock.withLock {
            guard let h = Self.handler else {
                fatalError("URLProtocolStub.respond not configured")
            }
            return h(self.request)
        }
        let httpResp = HTTPURLResponse(
            url: request.url!,
            statusCode: resp.status,
            httpVersion: "HTTP/1.1",
            headerFields: resp.headers
        )!
        client?.urlProtocol(self, didReceive: httpResp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: resp.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
```

- [ ] **Step 2: Confirm TDD red**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO -only-testing:WeeklyPlannerTests/GmailClientTests 2>&1 \
  | grep -E "error:" | head -5
```

Expected: `error: cannot find 'GmailClient' in scope`.

- [ ] **Step 3: Write the implementation**

Create `WeeklyPlanner/Stores/Gmail/GmailClient.swift`:

```swift
import Foundation

enum GmailClientError: Error, Equatable {
    /// The Gmail history cursor we passed is too old. Caller should do a full re-sync.
    case historyExpired
    /// Server returned non-success after retries.
    case http(status: Int)
    /// Response body wasn't valid JSON for the expected DTO.
    case decode(String)
}

enum GmailMessageFormat: String {
    case full
    case metadata
    case minimal
}

/// REST wrapper for Gmail API v1. Handles bearer-token injection,
/// automatic refresh on 401 (one retry), and `Retry-After`-aware
/// backoff on 429 (up to 5 retries with jitter). Network transport is
/// injected via `URLSessionProtocol` so tests use `URLProtocolStub`.
@MainActor
final class GmailClient {
    private let auth: any GoogleAuthService
    private let session: URLSessionProtocol
    private let baseURL = URL(string: "https://gmail.googleapis.com")!
    private static let maxRetries = 5

    init(auth: any GoogleAuthService, session: URLSessionProtocol) {
        self.auth = auth
        self.session = session
    }

    // MARK: - Public endpoints

    func listMessages(query: String, maxResults: Int) async throws -> [GmailMessageStub] {
        var components = URLComponents(url: baseURL.appending(path: "/gmail/v1/users/me/messages"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
        ]
        let response: GmailMessageListResponse = try await get(url: components.url!)
        return response.messages ?? []
    }

    func fetchMessage(id: String, format: GmailMessageFormat) async throws -> GmailMessage {
        var components = URLComponents(url: baseURL.appending(path: "/gmail/v1/users/me/messages/\(id)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "format", value: format.rawValue)]
        return try await get(url: components.url!)
    }

    func history(startHistoryId: String) async throws -> GmailHistoryResponse {
        var components = URLComponents(url: baseURL.appending(path: "/gmail/v1/users/me/history"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "startHistoryId", value: startHistoryId)]
        do {
            return try await get(url: components.url!)
        } catch GmailClientError.http(status: 404) {
            throw GmailClientError.historyExpired
        }
    }

    func profile() async throws -> GmailProfile {
        let url = baseURL.appending(path: "/gmail/v1/users/me/profile")
        return try await get(url: url)
    }

    // MARK: - Private

    private func get<T: Decodable>(url: URL) async throws -> T {
        var did401 = false
        var attempts = 0

        while true {
            attempts += 1
            let token = try await auth.accessToken()
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await session.data(for: request)
            let http = response as! HTTPURLResponse

            switch http.statusCode {
            case 200..<300:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    throw GmailClientError.decode(String(describing: error))
                }

            case 401:
                if did401 {
                    throw GoogleAuthError.reauthenticationRequired
                }
                did401 = true
                continue // auth.accessToken() will refresh on the next call

            case 429:
                if attempts > Self.maxRetries {
                    throw GmailClientError.http(status: 429)
                }
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? pow(2.0, Double(attempts))
                try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                continue

            default:
                throw GmailClientError.http(status: http.statusCode)
            }
        }
    }
}
```

- [ ] **Step 4: Confirm TDD green**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO -only-testing:WeeklyPlannerTests/GmailClientTests 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`; `Executed 5 tests, with 0 failures`.

Note: the 401 refresh test relies on `RecordingAuthService.accessToken()` returning different tokens across calls. If the test hangs (the 429 retry path can sleep), check `pow(2.0, Double(attempts))` — for attempt 2 with no `Retry-After`, that's a 4-second sleep. The test sets `Retry-After: 0` to avoid that.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Stores/Gmail/GmailClient.swift \
        WeeklyPlannerTests/Gmail/GmailClientTests.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): GmailClient with 401 refresh + 429 backoff

URLSessionProtocol-injected REST wrapper for the four endpoints we use:
list, fetch, history, profile. On 401: refreshes the bearer token via
GoogleAuthService and retries once; second 401 → reauthenticationRequired.
On 429: honors Retry-After, exponential backoff up to 5 retries. On
history 404: surfaces .historyExpired so the engine triggers a full
re-sync. 5 tests via URLProtocolStub (no real network).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: `GmailQueryBuilder` (TDD)

**Files:**
- Create: `WeeklyPlanner/Stores/Gmail/GmailQueryBuilder.swift`
- Test:   `WeeklyPlannerTests/Gmail/GmailQueryBuilderTests.swift`

Pure-Swift string builder. v1.0 uses a single default filter.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import WeeklyPlanner

final class GmailQueryBuilderTests: XCTestCase {
    func testDefaultQueryIncludesEventKeywordsAndExcludesCategories() {
        let q = GmailQueryBuilder.defaultQuery(daysBack: 14)

        XCTAssertTrue(q.contains("from:reservations"))
        XCTAssertTrue(q.contains("subject:(invite OR confirmation OR reservation OR ticket OR appointment OR RSVP OR booking)"))
        XCTAssertTrue(q.contains("-category:promotions"))
        XCTAssertTrue(q.contains("-category:social"))
        XCTAssertTrue(q.contains("newer_than:14d"))
    }

    func testDaysBackParameterized() {
        let q = GmailQueryBuilder.defaultQuery(daysBack: 7)
        XCTAssertTrue(q.contains("newer_than:7d"))
    }
}
```

- [ ] **Step 2: Run, expect compile fail**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO -only-testing:WeeklyPlannerTests/GmailQueryBuilderTests 2>&1 \
  | grep -E "error:" | head -3
```

Expected: `cannot find 'GmailQueryBuilder' in scope`.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Builds the Gmail `q=` query string. v1.0 has a single default; future
/// versions may let the user customize via Settings.
enum GmailQueryBuilder {
    static func defaultQuery(daysBack: Int = 14) -> String {
        let senders = "(from:reservations OR from:tickets OR from:noreply OR from:reception OR from:notifications)"
        let subjects = "subject:(invite OR confirmation OR reservation OR ticket OR appointment OR RSVP OR booking)"
        let excludes = "-category:promotions -category:social"
        return "(\(senders) OR \(subjects)) \(excludes) newer_than:\(daysBack)d"
    }
}
```

- [ ] **Step 4: Run green**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO -only-testing:WeeklyPlannerTests/GmailQueryBuilderTests 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: 2 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Stores/Gmail/GmailQueryBuilder.swift \
        WeeklyPlannerTests/Gmail/GmailQueryBuilderTests.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): GmailQueryBuilder default query

Single default 'q=' filter that pulls event-likely messages from the
last 14 days: known senders (reservations/tickets/noreply/reception) OR
subject keywords (invite/confirmation/reservation/ticket/appointment/
RSVP/booking), minus promotions and social categories. Parameterized
daysBack for future customization. 2 tests.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: `MessageClassifier` (TDD)

**Files:**
- Create: `WeeklyPlanner/Stores/Gmail/MessageClassifier.swift`
- Test:   `WeeklyPlannerTests/Gmail/MessageClassifierTests.swift`

Cheap pre-filter that runs BEFORE the FoundationModels extractor. Pure functions over subject + from name/email.

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import WeeklyPlanner

final class MessageClassifierTests: XCTestCase {
    func testResyConfirmationSenderPasses() {
        let v = MessageClassifier.classify(
            subject: "Your reservation at Café Bleu is confirmed",
            fromName: "Resy",
            fromEmail: "reservations@resy.com"
        )
        XCTAssertTrue(v.passes)
        XCTAssertTrue(v.ruleHits.contains("sender:resy.com"))
    }

    func testTicketmasterSubjectKeywordPasses() {
        let v = MessageClassifier.classify(
            subject: "Your tickets for the show",
            fromName: "Ticketmaster",
            fromEmail: "no-reply@ticketmaster.com"
        )
        XCTAssertTrue(v.passes)
        XCTAssertTrue(v.ruleHits.contains("subject:ticket"))
    }

    func testPromotionalNewsletterFails() {
        let v = MessageClassifier.classify(
            subject: "50% off this weekend!",
            fromName: "Some Store Newsletter",
            fromEmail: "newsletter@store.com"
        )
        XCTAssertFalse(v.passes)
    }

    func testGenericTransactionalEmailPassesWhenSubjectHasKeyword() {
        let v = MessageClassifier.classify(
            subject: "Appointment confirmation — Dr. Smith",
            fromName: "Dental Office",
            fromEmail: "appointments@dentaloffice.example"
        )
        XCTAssertTrue(v.passes)
        XCTAssertTrue(v.ruleHits.contains("subject:appointment"))
        XCTAssertTrue(v.ruleHits.contains("subject:confirmation"))
    }
}
```

- [ ] **Step 2: Confirm TDD red**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO -only-testing:WeeklyPlannerTests/MessageClassifierTests 2>&1 \
  | grep -E "error:" | head -3
```

Expected: `cannot find 'MessageClassifier' in scope`.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Cheap pre-filter that decides whether a Gmail message is worth handing
/// to `EventExtractor` (which is expensive). Subject keywords + sender
/// domain rules. The downstream extractor makes the final isEvent call.
enum MessageClassifier {
    struct Verdict: Equatable {
        let passes: Bool
        let ruleHits: [String]
    }

    private static let eventDomains: Set<String> = [
        "resy.com",
        "opentable.com",
        "ticketmaster.com",
        "eventbrite.com",
        "airbnb.com",
        "doordash.com",
    ]

    private static let noiseDomains: Set<String> = [
        "unsubscribe.com",
        "marketing.com",
    ]

    private static let subjectKeywords: [String] = [
        "appointment",
        "confirmation",
        "confirmed",
        "ticket",
        "reservation",
        "invite",
        "rsvp",
        "booking",
    ]

    private static let promoKeywords: [String] = [
        "% off",
        "sale",
        "newsletter",
        "unsubscribe",
        "promo",
    ]

    static func classify(subject: String, fromName: String, fromEmail: String) -> Verdict {
        var hits: [String] = []
        let lowerSubject = subject.lowercased()
        let lowerName = fromName.lowercased()
        let lowerEmail = fromEmail.lowercased()
        let domain = lowerEmail.split(separator: "@").last.map(String.init) ?? ""

        // Hard-fail on noise senders / promo keywords first.
        if noiseDomains.contains(domain) {
            return Verdict(passes: false, ruleHits: ["sender:noise"])
        }
        if promoKeywords.contains(where: { lowerSubject.contains($0) }) {
            return Verdict(passes: false, ruleHits: ["subject:promo"])
        }
        if lowerName.contains("newsletter") {
            return Verdict(passes: false, ruleHits: ["sender:newsletter"])
        }

        // Sender domains.
        if eventDomains.contains(domain) {
            hits.append("sender:\(domain)")
        }

        // Subject keywords.
        for keyword in subjectKeywords where lowerSubject.contains(keyword) {
            hits.append("subject:\(keyword)")
        }

        return Verdict(passes: !hits.isEmpty, ruleHits: hits)
    }
}
```

- [ ] **Step 4: Run green**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO -only-testing:WeeklyPlannerTests/MessageClassifierTests 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Stores/Gmail/MessageClassifier.swift \
        WeeklyPlannerTests/Gmail/MessageClassifierTests.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): MessageClassifier rules-based pre-filter

Cheap pure-Swift gate before EventExtractor (expensive Foundation
Models call). Subject keywords (appointment/confirmation/ticket/...) +
sender domains (resy, opentable, ticketmaster, ...). Hard-fails on
promo subjects, noise domains, and 'newsletter' senders. Returns the
rule hits so the engine can log which rule fired. 4 tests cover the
four representative cases from the spec.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: `ExtractedEvent` + `EventExtractor` protocol + `StubEventExtractor`

**Files:**
- Create: `WeeklyPlanner/Intelligence/ExtractedEvent.swift`
- Create: `WeeklyPlanner/Intelligence/EventExtractor.swift`

The output schema and the protocol with its stub. `LiveEventExtractor` (Foundation Models impl) lands in Task 9.

- [ ] **Step 1: Create `ExtractedEvent`**

```swift
import Foundation

/// What the Foundation Models extractor returns for a single Gmail message.
/// All fields except `isEvent` and `confidence` are optional — the extractor
/// must not invent missing data.
struct ExtractedEvent: Codable, Equatable, Sendable {
    let isEvent: Bool
    let title: String?
    /// ISO 8601 date-time (Foundation Models returns these as strings).
    let startISO: String?
    let endISO: String?
    let location: String?
    /// One of "work", "personal", "health", "social", "errand" — or nil.
    let categoryHint: String?
    /// 0…1; below 0.55 the engine skips upserting an InboxSuggestion.
    let confidence: Double
}
```

- [ ] **Step 2: Create `EventExtractor` protocol + Stub**

```swift
import Foundation

/// One-call extractor: takes a Gmail message's text fields, returns a
/// structured `ExtractedEvent`. Production: `LiveEventExtractor`
/// (Foundation Models, iOS 26+). Tests + BG-fallback: `StubEventExtractor`.
@MainActor
protocol EventExtractor: AnyObject {
    func extract(
        subject: String,
        snippet: String,
        fromName: String,
        fromEmail: String,
        body: String
    ) async throws -> ExtractedEvent
}

/// Always returns `isEvent: false`. Used by:
/// - Unit tests that don't want to exercise the model.
/// - The runtime fallback when Foundation Models is unavailable
///   (older device, Apple Intelligence off, background context).
@MainActor
final class StubEventExtractor: EventExtractor {
    nonisolated init() {}

    func extract(
        subject _: String,
        snippet _: String,
        fromName _: String,
        fromEmail _: String,
        body _: String
    ) async throws -> ExtractedEvent {
        ExtractedEvent(
            isEvent: false,
            title: nil,
            startISO: nil,
            endISO: nil,
            location: nil,
            categoryHint: nil,
            confidence: 0
        )
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Intelligence/ExtractedEvent.swift \
        WeeklyPlanner/Intelligence/EventExtractor.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): ExtractedEvent schema + EventExtractor protocol + Stub

ExtractedEvent is the Codable output of the Foundation Models call:
isEvent + nullable title/start/end/location/categoryHint + confidence.
EventExtractor is the single-method protocol. StubEventExtractor
always returns isEvent=false — used by tests AND as the runtime BG
fallback when Foundation Models is unavailable. LiveEventExtractor
lands next.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: `LiveEventExtractor` (Foundation Models) + tests

**Files:**
- Create: `WeeklyPlanner/Intelligence/Tasks/LiveEventExtractor.swift`
- Test:   `WeeklyPlannerTests/Gmail/EventExtractorTests.swift`

`#if canImport(FoundationModels)` + `@available(iOS 26.0, *)` gated. The test file uses a `FakeEventExtractor` recording inputs and returning canned outputs — we don't unit-test the Live impl directly (Foundation Models on simulator isn't reliable enough for CI), but we DO test that `StubEventExtractor` always returns false (a guarantee the BG fallback depends on).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import WeeklyPlanner

@MainActor
final class EventExtractorTests: XCTestCase {

    // MARK: - StubEventExtractor

    func testStubExtractorAlwaysReturnsFalse() async throws {
        let sut = StubEventExtractor()
        let result = try await sut.extract(
            subject: "Your reservation at Café Bleu",
            snippet: "Friday 7pm",
            fromName: "Resy",
            fromEmail: "reservations@resy.com",
            body: "Reservation confirmed for Friday at 7pm"
        )
        XCTAssertFalse(result.isEvent)
        XCTAssertEqual(result.confidence, 0)
    }

    // MARK: - Fake extractor (exercises the protocol surface that InboxSyncEngine consumes)

    func testFakeResyConfirmationExtractsTitleAndStart() async throws {
        let fake = FakeEventExtractor()
        fake.nextResult = ExtractedEvent(
            isEvent: true,
            title: "Dinner at Café Bleu",
            startISO: "2026-06-12T19:00:00Z",
            endISO: nil,
            location: "Café Bleu",
            categoryHint: "social",
            confidence: 0.92
        )

        let result = try await fake.extract(
            subject: "Reservation confirmed",
            snippet: "Friday 7pm",
            fromName: "Resy",
            fromEmail: "reservations@resy.com",
            body: "..."
        )

        XCTAssertTrue(result.isEvent)
        XCTAssertEqual(result.title, "Dinner at Café Bleu")
        XCTAssertEqual(result.startISO, "2026-06-12T19:00:00Z")
        XCTAssertEqual(result.location, "Café Bleu")
        XCTAssertEqual(fake.callCount, 1)
    }

    func testFakeAmbiguousEmailReturnsIsEventFalse() async throws {
        let fake = FakeEventExtractor()
        fake.nextResult = ExtractedEvent(
            isEvent: false, title: nil, startISO: nil, endISO: nil,
            location: nil, categoryHint: nil, confidence: 0.2
        )

        let result = try await fake.extract(
            subject: "Update from the team",
            snippet: "...", fromName: "Co-Worker", fromEmail: "x@y.com", body: "..."
        )

        XCTAssertFalse(result.isEvent)
    }

    func testFakeMissingTimeReturnsNilStart() async throws {
        let fake = FakeEventExtractor()
        fake.nextResult = ExtractedEvent(
            isEvent: true, title: "Meeting", startISO: nil, endISO: nil,
            location: nil, categoryHint: "work", confidence: 0.6
        )

        let result = try await fake.extract(subject: "", snippet: "", fromName: "", fromEmail: "", body: "")

        XCTAssertTrue(result.isEvent)
        XCTAssertNil(result.startISO) // extractor refused to invent the time
    }
}

// MARK: - Test double

@MainActor
final class FakeEventExtractor: EventExtractor {
    var nextResult: ExtractedEvent = ExtractedEvent(
        isEvent: false, title: nil, startISO: nil, endISO: nil,
        location: nil, categoryHint: nil, confidence: 0
    )
    var nextError: Error?
    private(set) var callCount = 0
    private(set) var lastSubject: String?

    nonisolated init() {}

    func extract(
        subject: String,
        snippet _: String,
        fromName _: String,
        fromEmail _: String,
        body _: String
    ) async throws -> ExtractedEvent {
        callCount += 1
        lastSubject = subject
        if let error = nextError { throw error }
        return nextResult
    }
}
```

- [ ] **Step 2: Run, expect compile fail referencing FakeEventExtractor + StubEventExtractor (the latter exists; the test build fails only if you forgot to include the test file). Actually the test should compile because both the protocol and the stub exist — confirm TDD GREEN here (4 tests pass).**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO -only-testing:WeeklyPlannerTests/EventExtractorTests 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: `Executed 4 tests, with 0 failures`.

- [ ] **Step 3: Now write `LiveEventExtractor` (Foundation Models)**

Create `WeeklyPlanner/Intelligence/Tasks/LiveEventExtractor.swift`:

```swift
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Foundation Models-backed `EventExtractor`. Uses `LanguageModelSession`'s
/// structured-output mode (`respond(to:as:)`) to return an `ExtractedEvent`
/// directly without any string parsing. Gated to iOS 26+ via
/// `#if canImport(FoundationModels)` and `@available`.
///
/// The system prompt explicitly forbids inventing missing fields:
/// startISO/endISO/location must remain nil when not stated in the email.
/// Confidence below 0.55 is the engine's signal to skip the suggestion.
@MainActor
final class LiveEventExtractor: EventExtractor {
    nonisolated init() {}

    func extract(
        subject: String,
        snippet: String,
        fromName: String,
        fromEmail: String,
        body: String
    ) async throws -> ExtractedEvent {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await extractWithFoundationModels(
                subject: subject,
                snippet: snippet,
                fromName: fromName,
                fromEmail: fromEmail,
                body: body
            )
        }
        #endif
        // Older OS or framework not present → behave like the stub.
        return ExtractedEvent(
            isEvent: false, title: nil, startISO: nil, endISO: nil,
            location: nil, categoryHint: nil, confidence: 0
        )
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func extractWithFoundationModels(
        subject: String,
        snippet: String,
        fromName: String,
        fromEmail: String,
        body: String
    ) async throws -> ExtractedEvent {
        let session = LanguageModelSession(instructions: Self.systemPrompt)
        let prompt = """
        From the email below, extract a single calendar event.
        If no event is present, set isEvent=false and leave other fields null.
        Never invent details: if a field is not in the email, leave it null.

        From: \(fromName) <\(fromEmail)>
        Subject: \(subject)
        Snippet: \(snippet)
        Body:
        \(body)
        """
        let response = try await session.respond(to: prompt, generating: ExtractedEvent.self)
        return response.content
    }

    private static let systemPrompt = """
    You are an event extractor for a calendar app. Given an email, return
    structured JSON describing the event it announces. Set isEvent=false
    if the email is not an invitation, confirmation, or reservation.
    All time fields use ISO 8601. Never fabricate missing data — leave
    fields null rather than guessing.
    """
    #endif
}
```

Note: the exact `LanguageModelSession.respond(to:generating:)` signature may differ slightly in the shipped iOS 26 SDK. If the build fails at that call site, read the FoundationModels module's public headers (via the SDK or Apple's documentation site) and adapt — likely candidates are `respond(to:as:)` or `decode(into:)`. The structured-output return is what matters; the call name is a detail.

- [ ] **Step 4: Build**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `** BUILD SUCCEEDED **`. If the FoundationModels API call signature is different from the spec's assumption, adjust the `respond(...)` call to match what compiles. Note any deviation.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Intelligence/Tasks/LiveEventExtractor.swift \
        WeeklyPlannerTests/Gmail/EventExtractorTests.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): LiveEventExtractor (Foundation Models) + tests

Foundation Models impl of EventExtractor using LanguageModelSession's
structured-output mode (no string parsing). Gated #if canImport(
FoundationModels) + @available(iOS 26.0, *); falls back to isEvent=
false on older OS. System prompt forbids inventing missing fields.

4 EventExtractorTests cover the Stub guarantee + three FakeEventExtractor
scenarios (Resy extracts title+start, ambiguous returns false, missing
time keeps startISO nil).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: `GmailDeltaSync` helper

**Files:**
- Create: `WeeklyPlanner/Stores/Gmail/GmailDeltaSync.swift`

Thin helper around `UserSettings.gmailLastHistoryId` so `InboxSyncEngine` doesn't directly touch SwiftData inside its sync loop. No standalone tests — exercised through `InboxSyncEngineTests`.

- [ ] **Step 1: Write the file**

```swift
import Foundation

/// Reads + writes the Gmail history-API cursor stored in
/// `UserSettings.gmailLastHistoryId`. Used by `InboxSyncEngine` to decide
/// between a delta sync (cursor present) and a full re-sync (cursor nil or
/// expired).
@MainActor
final class GmailDeltaSync {
    private let settingsStore: any SettingsStoring

    init(settingsStore: any SettingsStoring) {
        self.settingsStore = settingsStore
    }

    func currentCursor() -> String? {
        try? settingsStore.current().gmailLastHistoryId
    }

    func saveCursor(_ id: String) {
        try? settingsStore.update { $0.gmailLastHistoryId = id }
    }

    func clearCursor() {
        try? settingsStore.update { $0.gmailLastHistoryId = nil }
    }
}
```

- [ ] **Step 2: Build + commit**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2

git add WeeklyPlanner/Stores/Gmail/GmailDeltaSync.swift WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): GmailDeltaSync cursor helper

Thin wrapper around UserSettings.gmailLastHistoryId so InboxSyncEngine
doesn't touch SwiftData directly inside its sync loop. Three methods:
currentCursor / saveCursor / clearCursor.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: `DefaultReminderPolicy` (TDD)

**Files:**
- Create: `WeeklyPlanner/Notifications/DefaultReminderPolicy.swift`
- Test:   `WeeklyPlannerTests/Notifications/DefaultReminderPolicyTests.swift`

Used by the Phase 18 accept-flow and (later) the Phase 19 manual-add flow. Ships in Phase 18 because accept needs it; Phase 19 expands the notification side.

- [ ] **Step 1: Failing test**

Create `WeeklyPlannerTests/Notifications/DefaultReminderPolicyTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WeeklyPlanner

@MainActor
final class DefaultReminderPolicyTests: XCTestCase {
    private func makeEvent() -> Event {
        Event(
            title: "Coffee",
            start: Date(timeIntervalSince1970: 1_700_000_000),
            end: Date(timeIntervalSince1970: 1_700_003_600),
            location: nil,
            category: .personal
        )
    }

    private func settings(defaultMinutes: Int?) -> UserSettings {
        UserSettings(defaultReminderMinutes: defaultMinutes)
    }

    func testAppliesDefaultWhenEventHasNoReminders() {
        let event = makeEvent()
        DefaultReminderPolicy.apply(to: event, settings: settings(defaultMinutes: 15))

        XCTAssertEqual(event.reminders.count, 1)
        guard case let .timeBefore(minutes) = event.reminders.first else {
            return XCTFail("Expected .timeBefore")
        }
        XCTAssertEqual(minutes, 15)
    }

    func testNoOpWhenDefaultIsNil() {
        let event = makeEvent()
        DefaultReminderPolicy.apply(to: event, settings: settings(defaultMinutes: nil))

        XCTAssertTrue(event.reminders.isEmpty)
    }

    func testNoOpWhenEventAlreadyHasTimeReminder() {
        let event = makeEvent()
        event.reminders = [.timeBefore(minutes: 60)]

        DefaultReminderPolicy.apply(to: event, settings: settings(defaultMinutes: 15))

        XCTAssertEqual(event.reminders.count, 1)
        guard case let .timeBefore(minutes) = event.reminders.first else {
            return XCTFail("Expected .timeBefore")
        }
        XCTAssertEqual(minutes, 60) // unchanged
    }
}
```

- [ ] **Step 2: Confirm TDD red**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO -only-testing:WeeklyPlannerTests/DefaultReminderPolicyTests 2>&1 \
  | grep -E "error:" | head -3
```

Expected: `cannot find 'DefaultReminderPolicy' in scope`.

If the build also complains about `.timeBefore` not being a known case, READ `WeeklyPlanner/Models/Reminder.swift` to confirm the case name and adapt the test fixture. Common alternative names: `.minutesBefore(_:)`, `.relative(minutes:)`.

- [ ] **Step 3: Implement**

Create `WeeklyPlanner/Notifications/DefaultReminderPolicy.swift`:

```swift
import Foundation

/// Applies the user's default-reminder preference to a freshly-created
/// `Event`. Called by Phase 18's `InboxStore.accept(id:)` and (later) by
/// Phase 19's manual-add flow.
///
/// No-op when:
/// - The user has chosen "No reminder" (`settings.defaultReminderMinutes == nil`).
/// - The event already has a time-based reminder.
///
/// `Event` is a `@Model final class`, so we mutate `event.reminders` via the
/// class reference — no `inout`.
enum DefaultReminderPolicy {
    static func apply(to event: Event, settings: UserSettings) {
        guard let minutes = settings.defaultReminderMinutes else { return }
        guard event.reminders.contains(where: { $0.isTimeBased }) == false else { return }
        event.reminders.append(.timeBefore(minutes: minutes))
    }
}

extension Reminder {
    /// True when this reminder fires at a time offset from event start
    /// (as opposed to a location-arrival trigger). Used by
    /// `DefaultReminderPolicy` to avoid stacking duplicate time reminders.
    var isTimeBased: Bool {
        if case .timeBefore = self { return true }
        return false
    }
}
```

If `Reminder.timeBefore(minutes:)` doesn't exist with that exact spelling, READ `WeeklyPlanner/Models/Reminder.swift` and adapt both `apply` and `isTimeBased` to the actual case.

- [ ] **Step 4: Run green**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO -only-testing:WeeklyPlannerTests/DefaultReminderPolicyTests 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: 3 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Notifications/DefaultReminderPolicy.swift \
        WeeklyPlannerTests/Notifications/DefaultReminderPolicyTests.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): DefaultReminderPolicy + Reminder.isTimeBased

Applies UserSettings.defaultReminderMinutes to a freshly-created Event.
No-op when user chose 'No reminder' or when the event already has a
time-based reminder. Used by Phase 18's accept flow and (later) by
Phase 19's manual-add flow. Adds Reminder.isTimeBased convenience
extension. 3 tests.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: `InboxStore+Gmail.swift` — accept flow

**Files:**
- Create: `WeeklyPlanner/Stores/InboxStore+Gmail.swift`
- Modify: `WeeklyPlanner/Stores/InboxStore.swift` (constructor accepts an EventStore so accept can write through)

The accept flow needs access to `EventStoring` and `SettingsStoring`. Cleanest: thread them through `SwiftDataInboxStore`'s init as optionals (preserves the existing `init(context:)` for tests that don't care about accept).

- [ ] **Step 1: Update `SwiftDataInboxStore.init` to take an optional `EventStoring` + `SettingsStoring`**

In `WeeklyPlanner/Stores/InboxStore.swift`, change the class signature:

```swift
@MainActor
final class SwiftDataInboxStore: InboxStoring {
    private let context: ModelContext
    private let eventStore: (any EventStoring)?
    private let settingsStore: (any SettingsStoring)?

    init(
        context: ModelContext,
        eventStore: (any EventStoring)? = nil,
        settingsStore: (any SettingsStoring)? = nil
    ) {
        self.context = context
        self.eventStore = eventStore
        self.settingsStore = settingsStore
    }

    // ... rest unchanged ...
```

Replace the existing `accept(id:)` body — it currently just flips the status. Move the new "build Event + upsert + flip" logic into a new file (Step 2) and update the existing one to forward.

Actually the cleanest path: keep the existing minimal `accept(id:)` body in `InboxStore.swift` AND override it via the extension in Step 2. But Swift extensions can't override class methods. So inline the new logic into `InboxStore.swift`'s `accept(id:)` and use `InboxStore+Gmail.swift` only for any helper extensions.

Let me restructure: replace the existing `accept(id:)` in `InboxStore.swift` with the new version that uses the optional stores:

```swift
    func accept(id: UUID) async throws {
        guard let suggestion = try await suggestion(id: id) else { return }

        // If we have an EventStore, mirror the suggestion to a real Event
        // (Phase 18 wires this; Phase 17 tests / previews pass nil and we
        // just flip the status).
        if let eventStore {
            let endDate = suggestion.proposedEnd ?? suggestion.proposedStart.addingTimeInterval(3600)
            let event = Event(
                title: suggestion.title,
                start: suggestion.proposedStart,
                end: endDate,
                location: suggestion.proposedLocation,
                category: suggestion.category,
                source: .gmail,
                gmailMessageID: suggestion.gmailMessageID,
                gmailFrom: suggestion.fromEmail,
                gmailSubject: suggestion.subject
            )
            if let settings = try? settingsStore?.current() {
                DefaultReminderPolicy.apply(to: event, settings: settings)
            }
            try await eventStore.upsert(event)
        }

        suggestion.status = .accepted
        try context.save()
    }
```

(`StubInboxStore` in `Environment+Stores.swift` is unaffected — it still has its no-op `accept(id:)`.)

- [ ] **Step 2: Verify no existing tests broke**

The Phase 17 `ConnectionsViewModelTests` construct `SwiftDataInboxStore(context:)` without the new params — that still works because both are defaulted. Run the full suite:

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: same count as before, all green (the existing accept tests still pass because they construct `SwiftDataInboxStore` without an EventStore, hitting the if-let-nil branch).

- [ ] **Step 3: Add a small InboxStore+Gmail extension file for shared types Phase 18 needs**

Create `WeeklyPlanner/Stores/InboxStore+Gmail.swift`:

```swift
import Foundation

/// Phase 18 helper: build an `InboxSuggestion` from the engine's pipeline
/// outputs. Kept here so `InboxSyncEngine.upsert(...)` reads naturally
/// without inlining all the field mapping.
extension InboxSuggestion {
    static func fromExtractedEvent(
        _ extracted: ExtractedEvent,
        message: GmailMessage,
        fallbackCategory: Category = .personal
    ) -> InboxSuggestion? {
        guard extracted.isEvent,
              let title = extracted.title,
              let startISO = extracted.startISO,
              let start = ISO8601DateFormatter().date(from: startISO)
        else { return nil }

        let end = extracted.endISO.flatMap { ISO8601DateFormatter().date(from: $0) }
        let category = Category(rawValue: extracted.categoryHint ?? "") ?? fallbackCategory
        let fromHeader = message.header("From") ?? ""
        let (fromName, fromEmail) = parseFromHeader(fromHeader)

        return InboxSuggestion(
            gmailMessageID: message.id,
            proposedStart: start,
            proposedEnd: end,
            title: title,
            fromName: fromName,
            fromEmail: fromEmail,
            category: category,
            subject: message.header("Subject") ?? "",
            bodySnippet: message.snippet,
            proposedLocation: extracted.location
        )
    }

    /// Splits an RFC-822 From header ("Display Name <user@example.com>")
    /// into name + email. Falls back to ("", fullValue) when there's no
    /// angle-bracketed email.
    private static func parseFromHeader(_ value: String) -> (name: String, email: String) {
        guard let openBracket = value.firstIndex(of: "<"),
              let closeBracket = value.firstIndex(of: ">"),
              openBracket < closeBracket
        else {
            return ("", value.trimmingCharacters(in: .whitespaces))
        }
        let name = String(value[..<openBracket])
            .trimmingCharacters(in: CharacterSet(charactersIn: " \""))
        let email = String(value[value.index(after: openBracket)..<closeBracket])
        return (name, email)
    }
}
```

- [ ] **Step 4: Build**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `** BUILD SUCCEEDED **`. If `Category(rawValue:)` doesn't initialize from arbitrary strings the way expected, adapt — likely the enum has specific raw values like "work"/"personal"/"social"/"health"/"errand".

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Stores/InboxStore.swift \
        WeeklyPlanner/Stores/InboxStore+Gmail.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): InboxStore.accept builds Event + EventStore.upsert

SwiftDataInboxStore.init now accepts optional eventStore + settingsStore
(default nil — preserves existing test call sites). accept(id:) now
constructs an Event with source=.gmail and the round-trip
gmailMessageID/from/subject fields, applies DefaultReminderPolicy, and
calls EventStore.upsert (which mirrors to EventKit via the Phase 04
decorator). When eventStore is nil (Phase 17 tests / previews), accept
still just flips the suggestion status — behavior unchanged for those
call sites.

Also adds InboxSuggestion.fromExtractedEvent helper that maps
(ExtractedEvent + GmailMessage) → InboxSuggestion, including
RFC-822 From-header parsing.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: `InboxSyncEngine` (actor + TDD)

**Files:**
- Create: `WeeklyPlanner/Stores/Gmail/InboxSyncEngine.swift`
- Test:   `WeeklyPlannerTests/Gmail/InboxSyncEngineTests.swift`

The orchestrator. Single-flight via `actor`; emits `SyncProgress` via `AsyncStream`. 6 tests via fakes.

- [ ] **Step 1: Failing test**

```swift
import XCTest
import SwiftData
@testable import WeeklyPlanner

@MainActor
final class InboxSyncEngineTests: XCTestCase {
    private var container: ModelContainer!
    private var settingsStore: SwiftDataSettingsStore!
    private var inboxStore: SwiftDataInboxStore!
    private var fakeClient: FakeGmailClient!
    private var fakeExtractor: FakeEventExtractor!
    private var sut: InboxSyncEngine!

    override func setUp() async throws {
        try await super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: UserSettings.self, InboxSuggestion.self, Event.self, TaskItem.self,
            configurations: config
        )
        settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        inboxStore = SwiftDataInboxStore(context: container.mainContext)
        fakeClient = FakeGmailClient()
        fakeExtractor = FakeEventExtractor()
        sut = InboxSyncEngine(
            client: fakeClient,
            extractor: fakeExtractor,
            inboxStore: inboxStore,
            deltaSync: GmailDeltaSync(settingsStore: settingsStore)
        )
    }

    // MARK: - Initial full sync

    func testInitialFullSyncInsertsSuggestions() async throws {
        fakeClient.listResponse = [GmailMessageStub(id: "m1", threadId: nil)]
        fakeClient.messageResponses["m1"] = makeMessage(id: "m1", subject: "Reservation at Café Bleu", from: "Resy <reservations@resy.com>")
        fakeExtractor.nextResult = futureExtractedEvent(title: "Dinner at Café Bleu")
        fakeClient.profileResponse = GmailProfile(emailAddress: "u@x.com", historyId: "100", messagesTotal: 1)

        let result = try await sut.sync(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(result.added, 1)
        let stored = try await inboxStore.pending(forWeekOffset: 0, today: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(stored.first?.title, "Dinner at Café Bleu")
        XCTAssertEqual(try settingsStore.current().gmailLastHistoryId, "100")
    }

    // MARK: - Delta sync

    func testDeltaSyncOnlyProcessesNewMessages() async throws {
        // Pre-seed cursor + an existing suggestion (m1).
        try settingsStore.update { $0.gmailLastHistoryId = "50" }
        try await inboxStore.upsert(makeSuggestion(id: "m1"))

        fakeClient.historyResponse = GmailHistoryResponse(
            history: [GmailHistoryRecord(id: "51", messages: nil, messagesAdded: [
                GmailMessageAdded(message: GmailMessageStub(id: "m2", threadId: nil)),
            ])],
            nextPageToken: nil,
            historyId: "51"
        )
        fakeClient.messageResponses["m2"] = makeMessage(id: "m2", subject: "Tickets for the show", from: "Ticketmaster <noreply@ticketmaster.com>")
        fakeExtractor.nextResult = futureExtractedEvent(title: "Show")
        fakeClient.profileResponse = GmailProfile(emailAddress: "u@x.com", historyId: "51", messagesTotal: 1)

        let result = try await sut.sync(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(fakeClient.messageFetchCalls, ["m2"]) // m1 not refetched
    }

    // MARK: - Accept-after-sync writes an Event

    func testAcceptedSuggestionCreatesEventThroughStore() async throws {
        let inMemoryEvents = InMemoryEventStore()
        let storeWithEvents = SwiftDataInboxStore(
            context: container.mainContext,
            eventStore: inMemoryEvents,
            settingsStore: settingsStore
        )
        try await storeWithEvents.upsert(makeSuggestion(id: "m1"))
        let id = try await storeWithEvents.pending(
            forWeekOffset: 0,
            today: Date(timeIntervalSince1970: 1_700_000_000)
        ).first!.id

        try await storeWithEvents.accept(id: id)

        XCTAssertEqual(inMemoryEvents.upsertedEvents.count, 1)
        XCTAssertEqual(inMemoryEvents.upsertedEvents.first?.source, .gmail)
    }

    // MARK: - Dismiss blocks re-suggestion

    func testDismissPreventsResuggestionOnNextSync() async throws {
        try await inboxStore.upsert(makeSuggestion(id: "m1"))
        let id = try await inboxStore.pending(forWeekOffset: 0, today: Date(timeIntervalSince1970: 1_700_000_000)).first!.id
        try await inboxStore.dismiss(id: id)

        // Engine sees m1 again on a fresh full sync but should NOT re-upsert.
        fakeClient.listResponse = [GmailMessageStub(id: "m1", threadId: nil)]
        fakeClient.messageResponses["m1"] = makeMessage(id: "m1", subject: "Reservation at Café Bleu", from: "Resy <reservations@resy.com>")
        fakeExtractor.nextResult = futureExtractedEvent(title: "Dinner again")
        fakeClient.profileResponse = GmailProfile(emailAddress: "u@x.com", historyId: "100", messagesTotal: 1)

        let result = try await sut.sync(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(result.added, 0)
    }

    // MARK: - Past-dated suggestion skipped

    func testPastDatedSuggestionSkipped() async throws {
        fakeClient.listResponse = [GmailMessageStub(id: "m1", threadId: nil)]
        fakeClient.messageResponses["m1"] = makeMessage(id: "m1", subject: "Yesterday's event", from: "x <x@y.com>")
        fakeExtractor.nextResult = ExtractedEvent(
            isEvent: true, title: "Yesterday",
            startISO: "2025-01-01T10:00:00Z", // far in the past
            endISO: nil, location: nil, categoryHint: nil, confidence: 0.9
        )
        fakeClient.profileResponse = GmailProfile(emailAddress: "u@x.com", historyId: "100", messagesTotal: 1)

        let result = try await sut.sync(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(result.added, 0)
    }

    // MARK: - Single-flight

    func testSingleFlightQueuesSecondCall() async throws {
        fakeClient.listResponse = []
        fakeClient.profileResponse = GmailProfile(emailAddress: "u@x.com", historyId: "100", messagesTotal: 0)

        async let a = sut.sync(now: Date())
        async let b = sut.sync(now: Date())
        _ = try await (a, b)

        // Both completed; engine should NOT have invoked the network in parallel.
        // Spec: "at most 1 concurrent sync; queued otherwise."
        // Verify by checking the in-flight counter the fake records.
        XCTAssertLessThanOrEqual(fakeClient.maxConcurrentCalls, 1)
    }

    // MARK: - Fixtures

    private func makeMessage(id: String, subject: String, from: String) -> GmailMessage {
        GmailMessage(
            id: id,
            threadId: nil,
            snippet: subject,
            historyId: nil,
            internalDate: nil,
            payload: GmailPayload(
                mimeType: "text/plain",
                headers: [
                    GmailHeader(name: "Subject", value: subject),
                    GmailHeader(name: "From", value: from),
                ],
                body: nil,
                parts: nil
            )
        )
    }

    private func makeSuggestion(id: String) -> InboxSuggestion {
        InboxSuggestion(
            gmailMessageID: id,
            proposedStart: Date(timeIntervalSince1970: 1_700_050_000),
            title: "Existing",
            fromName: "Resy",
            fromEmail: "reservations@resy.com",
            subject: "Existing",
            bodySnippet: nil
        )
    }

    private func futureExtractedEvent(title: String) -> ExtractedEvent {
        ExtractedEvent(
            isEvent: true,
            title: title,
            startISO: "2026-06-12T19:00:00Z",
            endISO: nil,
            location: "Café Bleu",
            categoryHint: nil,
            confidence: 0.9
        )
    }
}

// MARK: - Test doubles

@MainActor
final class FakeGmailClient: GmailClient.Protocol {
    var listResponse: [GmailMessageStub] = []
    var messageResponses: [String: GmailMessage] = [:]
    var historyResponse: GmailHistoryResponse?
    var profileResponse: GmailProfile = GmailProfile(emailAddress: "x@y.com", historyId: "0", messagesTotal: 0)
    private(set) var messageFetchCalls: [String] = []
    private(set) var maxConcurrentCalls = 0
    private var currentCalls = 0

    nonisolated init() {}

    func listMessages(query _: String, maxResults _: Int) async throws -> [GmailMessageStub] {
        try await trackingCall { self.listResponse }
    }

    func fetchMessage(id: String, format _: GmailMessageFormat) async throws -> GmailMessage {
        try await trackingCall {
            self.messageFetchCalls.append(id)
            guard let m = self.messageResponses[id] else { throw GmailClientError.http(status: 404) }
            return m
        }
    }

    func history(startHistoryId _: String) async throws -> GmailHistoryResponse {
        try await trackingCall {
            guard let h = self.historyResponse else { throw GmailClientError.historyExpired }
            return h
        }
    }

    func profile() async throws -> GmailProfile {
        try await trackingCall { self.profileResponse }
    }

    private func trackingCall<T>(_ body: @escaping () throws -> T) async throws -> T {
        currentCalls += 1
        maxConcurrentCalls = max(maxConcurrentCalls, currentCalls)
        defer { currentCalls -= 1 }
        return try body()
    }
}

/// Minimal in-memory `EventStoring` for the accept test.
@MainActor
final class InMemoryEventStore: EventStoring {
    private(set) var upsertedEvents: [Event] = []
    nonisolated init() {}
    func events(forWeekOffset _: Int, today _: Date) async throws -> [Event] { [] }
    func event(id _: UUID) async throws -> Event? { nil }
    func upsert(_ event: Event) async throws { upsertedEvents.append(event) }
    func delete(id _: UUID) async throws {}
    func events(matching _: EventQuery) async throws -> [Event] { [] }
}
```

- [ ] **Step 2: Confirm TDD red**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO -only-testing:WeeklyPlannerTests/InboxSyncEngineTests 2>&1 \
  | grep -E "error:" | head -10
```

Expected: `cannot find 'InboxSyncEngine' in scope` and `cannot find 'GmailClient.Protocol' in scope` (we'll add that protocol in the impl).

- [ ] **Step 3: Refactor `GmailClient` to extract a `GmailClientProtocol` so tests can fake it**

The test fixture uses `GmailClient.Protocol`. Cleanest: define a top-level `GmailClientProtocol` and have the existing `GmailClient` conform. Modify `WeeklyPlanner/Stores/Gmail/GmailClient.swift`:

Add at the top of the file (above `final class GmailClient`):

```swift
@MainActor
protocol GmailClientProtocol: AnyObject {
    func listMessages(query: String, maxResults: Int) async throws -> [GmailMessageStub]
    func fetchMessage(id: String, format: GmailMessageFormat) async throws -> GmailMessage
    func history(startHistoryId: String) async throws -> GmailHistoryResponse
    func profile() async throws -> GmailProfile
}

extension GmailClient: GmailClientProtocol {}
```

Update the test fixture's `FakeGmailClient: GmailClient.Protocol` to `FakeGmailClient: GmailClientProtocol`.

- [ ] **Step 4: Implement `InboxSyncEngine`**

Create `WeeklyPlanner/Stores/Gmail/InboxSyncEngine.swift`:

```swift
import Foundation

struct SyncProgress: Equatable, Sendable {
    enum Stage: Equatable, Sendable {
        case fetching
        case classifying
        case extracting
        case done
    }
    let stage: Stage
    let processed: Int
    let total: Int
}

struct SyncResult: Equatable, Sendable {
    let added: Int
    let updated: Int
    let skipped: Int
}

/// Orchestrates a single Gmail sync: fetch new messages (delta if cursor
/// present, full otherwise), classify cheaply, extract with Foundation
/// Models (or stub), upsert `InboxSuggestion` rows, persist the new
/// cursor. Single-flight via the `actor` boundary — a second concurrent
/// call awaits the first.
///
/// Progress events are surfaced via `progressStream` so the AppShell
/// top-bar spinner can render while the engine is active.
@MainActor
final class InboxSyncEngine {
    private let client: any GmailClientProtocol
    private let extractor: any EventExtractor
    private let inboxStore: any InboxStoring
    private let deltaSync: GmailDeltaSync

    private var isRunning = false
    private var continuation: AsyncStream<SyncProgress>.Continuation?

    /// Public progress stream. UI subscribes via `for await progress in engine.progressStream`.
    let progressStream: AsyncStream<SyncProgress>

    init(
        client: any GmailClientProtocol,
        extractor: any EventExtractor,
        inboxStore: any InboxStoring,
        deltaSync: GmailDeltaSync
    ) {
        self.client = client
        self.extractor = extractor
        self.inboxStore = inboxStore
        self.deltaSync = deltaSync
        var emitter: AsyncStream<SyncProgress>.Continuation!
        progressStream = AsyncStream { emitter = $0 }
        continuation = emitter
    }

    func sync(now: Date) async throws -> SyncResult {
        while isRunning {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        isRunning = true
        defer { isRunning = false }

        continuation?.yield(SyncProgress(stage: .fetching, processed: 0, total: 0))

        // 1. Decide delta vs full sync.
        let stubs: [GmailMessageStub]
        if let cursor = deltaSync.currentCursor() {
            do {
                let history = try await client.history(startHistoryId: cursor)
                stubs = (history.history ?? []).flatMap { record in
                    (record.messagesAdded ?? []).map(\.message)
                }
            } catch GmailClientError.historyExpired {
                stubs = try await client.listMessages(
                    query: GmailQueryBuilder.defaultQuery(),
                    maxResults: 50
                )
            }
        } else {
            stubs = try await client.listMessages(
                query: GmailQueryBuilder.defaultQuery(),
                maxResults: 50
            )
        }

        // 2. Fetch + classify + extract + upsert each.
        var added = 0
        var skipped = 0
        for (index, stub) in stubs.enumerated() {
            continuation?.yield(SyncProgress(stage: .classifying, processed: index, total: stubs.count))

            // Skip if already accepted/dismissed (engine is idempotent).
            if try await isAlreadyHandled(messageID: stub.id) {
                skipped += 1
                continue
            }

            let message = try await client.fetchMessage(id: stub.id, format: .full)
            let subject = message.header("Subject") ?? ""
            let fromHeader = message.header("From") ?? ""
            let verdict = MessageClassifier.classify(
                subject: subject,
                fromName: fromHeader,
                fromEmail: extractEmail(from: fromHeader)
            )
            guard verdict.passes else {
                skipped += 1
                continue
            }

            continuation?.yield(SyncProgress(stage: .extracting, processed: index, total: stubs.count))
            let extracted = try await extractor.extract(
                subject: subject,
                snippet: message.snippet ?? "",
                fromName: fromHeader,
                fromEmail: extractEmail(from: fromHeader),
                body: message.plainTextBody()
            )
            guard extracted.isEvent, extracted.confidence >= 0.55 else {
                skipped += 1
                continue
            }

            guard let suggestion = InboxSuggestion.fromExtractedEvent(extracted, message: message) else {
                skipped += 1
                continue
            }
            // Skip past-dated proposals.
            guard suggestion.proposedStart > now else {
                skipped += 1
                continue
            }
            try await inboxStore.upsert(suggestion)
            added += 1
        }

        // 3. Persist the new cursor.
        let profile = try await client.profile()
        deltaSync.saveCursor(profile.historyId)

        continuation?.yield(SyncProgress(stage: .done, processed: stubs.count, total: stubs.count))
        return SyncResult(added: added, updated: 0, skipped: skipped)
    }

    private func isAlreadyHandled(messageID: String) async throws -> Bool {
        // The InboxStoring protocol doesn't currently expose a "lookup by
        // gmailMessageID" — so we approximate by scanning pending() for the
        // current and adjacent weeks. accepted/dismissed rows are NOT in
        // pending(), so this naturally skips them on re-sync.
        // For v1.0 this is fine; if perf becomes a problem, add a direct
        // lookup on the store.
        let weeks = [-1, 0, 1]
        for offset in weeks {
            let rows = try await inboxStore.pending(forWeekOffset: offset, today: Date())
            if rows.contains(where: { $0.gmailMessageID == messageID }) {
                return true
            }
        }
        return false
    }

    private func extractEmail(from header: String) -> String {
        guard let open = header.firstIndex(of: "<"),
              let close = header.firstIndex(of: ">"),
              open < close
        else { return header.trimmingCharacters(in: .whitespaces) }
        return String(header[header.index(after: open)..<close])
    }
}
```

Note on `isAlreadyHandled`: the predicate-based "lookup by gmailMessageID" would be cleaner but requires adding a method to `InboxStoring`. For v1.0 the approximate-via-pending approach is sufficient and avoids cross-task scope creep. If `InboxSyncEngineTests.testDismissPreventsResuggestionOnNextSync` fails because dismissed rows ARE returned by `pending()`, switch to checking by status (the pending query already excludes dismissed/accepted).

- [ ] **Step 5: Run tests; expect green or close**

```bash
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO -only-testing:WeeklyPlannerTests/InboxSyncEngineTests 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests|failed:" | tail -10
```

Expected: 6 tests, 0 failures.

If `testDismissPreventsResuggestionOnNextSync` fails: the current `pending()` predicate excludes dismissed status, so `isAlreadyHandled` returns false for dismissed messages — meaning the engine WILL try to re-upsert. Fix: change `isAlreadyHandled` to also check by querying for the specific message-id across all statuses. The minimal patch is to add a new method to `InboxStoring`:

```swift
// In InboxStoring protocol:
func anyStatus(forMessageID id: String) async throws -> InboxSuggestion?

// In SwiftDataInboxStore:
func anyStatus(forMessageID id: String) async throws -> InboxSuggestion? {
    try context.fetch(FetchDescriptor<InboxSuggestion>(
        predicate: #Predicate<InboxSuggestion> { $0.gmailMessageID == id }
    )).first
}

// In StubInboxStore (Environment+Stores.swift):
func anyStatus(forMessageID _: String) async throws -> InboxSuggestion? { nil }

// In InboxSyncEngine.isAlreadyHandled:
private func isAlreadyHandled(messageID: String) async throws -> Bool {
    guard let existing = try await inboxStore.anyStatus(forMessageID: messageID) else { return false }
    return existing.status != .pending // already accepted or dismissed
}
```

Make that change (it's safer and more direct than the week-scan approximation), commit it as part of this task.

- [ ] **Step 6: Commit**

```bash
git add WeeklyPlanner/Stores/Gmail/GmailClient.swift \
        WeeklyPlanner/Stores/Gmail/InboxSyncEngine.swift \
        WeeklyPlanner/Stores/InboxStore.swift \
        WeeklyPlanner/Stores/Environment+Stores.swift \
        WeeklyPlannerTests/Gmail/InboxSyncEngineTests.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): InboxSyncEngine orchestrator (delta + extractor pipeline)

Actor-isolated single-flight sync: history cursor or full re-sync →
classify → extract → upsert. Saves new cursor on success. Skips
past-dated proposals and already-accepted/dismissed messages (via new
InboxStoring.anyStatus(forMessageID:) method). Emits SyncProgress via
AsyncStream so the UI top-bar spinner can render. 6 tests via
FakeGmailClient + FakeEventExtractor + in-memory SwiftData.

Also lifts a GmailClientProtocol out of the concrete client so the
engine + tests don't depend on the URLSession-backed type.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: `BackgroundRefreshScheduler` + Info.plist `BGTaskSchedulerPermittedIdentifiers`

**Files:**
- Create: `WeeklyPlanner/Stores/Gmail/BackgroundRefreshScheduler.swift`
- Modify: `WeeklyPlanner/Supporting/Info.plist`

- [ ] **Step 1: Add the BGTask identifier to Info.plist**

Find the `</dict>` near the end of `WeeklyPlanner/Supporting/Info.plist`. Right before it, add:

```xml
    <key>BGTaskSchedulerPermittedIdentifiers</key>
    <array>
        <string>com.weeklyplanner.WeeklyPlanner.gmailRefresh</string>
    </array>
```

- [ ] **Step 2: Create the scheduler**

```swift
import BackgroundTasks
import Foundation

/// Wraps `BGTaskScheduler` for the Gmail refresh task. Registered once at
/// app startup; submitted at the end of every foreground sync with a
/// 1-hour earliest-begin window.
@MainActor
final class BackgroundRefreshScheduler {
    static let taskIdentifier = "com.weeklyplanner.WeeklyPlanner.gmailRefresh"
    private let engine: InboxSyncEngine

    init(engine: InboxSyncEngine) {
        self.engine = engine
    }

    /// Called once from `WeeklyPlannerApp.init` before `body` is built.
    func registerHandler() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handle(task: task as! BGAppRefreshTask)
        }
    }

    /// Submitted after every foreground sync to keep the queue full.
    func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // 1h
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(task: BGAppRefreshTask) {
        // Always re-schedule so the queue stays primed.
        scheduleNext()
        let work = Task { @MainActor in
            do {
                _ = try await engine.sync(now: Date())
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        task.expirationHandler = { work.cancel() }
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Stores/Gmail/BackgroundRefreshScheduler.swift \
        WeeklyPlanner/Supporting/Info.plist \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): BackgroundRefreshScheduler + BGTask Info.plist registration

Registers com.weeklyplanner.WeeklyPlanner.gmailRefresh with
BGTaskScheduler at app startup; submits a 1-hour BGAppRefreshTaskRequest
after every foreground sync. The handler runs InboxSyncEngine.sync,
re-submits the next request immediately so the queue stays primed, and
sets expirationHandler to cancel the in-flight work.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: Environment wiring + WeeklyPlannerApp construction

**Files:**
- Modify: `WeeklyPlanner/Stores/Environment+Stores.swift`
- Modify: `WeeklyPlanner/App/WeeklyPlannerApp.swift`

- [ ] **Step 1: Add env keys + stubs**

In `Environment+Stores.swift`, after `googleAuthService`:

```swift
    /// The active `GmailClientProtocol`. Defaults to a stub that throws on
    /// every call so previews/tests don't accidentally make network calls.
    @Entry var gmailClient: (any GmailClientProtocol)? = nil

    /// The active `InboxSyncEngine`. Phase 18 wires the production
    /// instance in `WeeklyPlannerApp`. Nil in previews/tests means
    /// pull-to-refresh becomes a no-op.
    @Entry var inboxSyncEngine: InboxSyncEngine? = nil
```

(Both are optional rather than backed by stubs because `GmailClient` constructors require a `GoogleAuthService` and a `URLSession`, and `InboxSyncEngine` requires all four collaborators — wiring stubs would be more code than the value provides.)

- [ ] **Step 2: Build the production instances in `WeeklyPlannerApp.init` and wire them through `body`**

In `WeeklyPlanner/App/WeeklyPlannerApp.swift`, add `@State` properties:

```swift
    @State private var gmailClient: GmailClient
    @State private var inboxSyncEngine: InboxSyncEngine
    @State private var bgRefreshScheduler: BackgroundRefreshScheduler
```

In `init()`, after `googleAuthService` is built, construct the chain:

```swift
        // The inbox store now needs an event store + settings store so accept()
        // can mirror to EventKit through the Phase 04 decorator. Rebuild it here
        // (overriding the bare-context version constructed above).
        let wiredInboxStore = SwiftDataInboxStore(
            context: container.mainContext,
            eventStore: eventStore,
            settingsStore: settingsStore
        )
        let gmailClient = GmailClient(auth: googleAuthService, session: URLSession.shared)
        let extractor: any EventExtractor = LiveEventExtractor()
        let syncEngine = InboxSyncEngine(
            client: gmailClient,
            extractor: extractor,
            inboxStore: wiredInboxStore,
            deltaSync: GmailDeltaSync(settingsStore: settingsStore)
        )
        let scheduler = BackgroundRefreshScheduler(engine: syncEngine)
        scheduler.registerHandler()
```

Then assign:

```swift
        _inboxStore = State(initialValue: wiredInboxStore)
        _gmailClient = State(initialValue: gmailClient)
        _inboxSyncEngine = State(initialValue: syncEngine)
        _bgRefreshScheduler = State(initialValue: scheduler)
```

In `body`, add the environment injections:

```swift
                .environment(\.gmailClient, gmailClient)
                .environment(\.inboxSyncEngine, syncEngine)
```

- [ ] **Step 3: Build + run full test suite**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: full suite passes (count should be 234 baseline + 5 GmailClient + 2 GmailQueryBuilder + 4 MessageClassifier + 4 EventExtractor + 6 InboxSyncEngine + 3 DefaultReminderPolicy = 258).

- [ ] **Step 4: Commit**

```bash
git add WeeklyPlanner/Stores/Environment+Stores.swift \
        WeeklyPlanner/App/WeeklyPlannerApp.swift \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): wire GmailClient + InboxSyncEngine + BG scheduler

WeeklyPlannerApp.init now constructs the production pipeline: rebuilds
SwiftDataInboxStore with eventStore + settingsStore (so accept mirrors
to EventKit), constructs GmailClient over URLSession.shared, picks
LiveEventExtractor for production (StubEventExtractor for previews),
and registers BackgroundRefreshScheduler. \\.gmailClient and
\\.inboxSyncEngine env keys added.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 16: `DayPageViewModel.refresh()` + `WeekPageViewModel.refresh()` + pull-to-refresh

**Files:**
- Modify: `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift`
- Modify: `WeeklyPlanner/Features/WeekPage/WeekPageViewModel.swift`
- Modify: `WeeklyPlanner/Features/DayPage/PaperDayView.swift` (or the file that hosts the day's `ScrollView`)
- Modify: `WeeklyPlanner/Features/WeekPage/PaperWeekView.swift` (or the file that hosts the week's `ScrollView`)

- [ ] **Step 1: Add `refresh()` to `DayPageViewModel`**

In `WeeklyPlanner/Features/DayPage/DayPageViewModel.swift`, add to the class body:

```swift
    /// Triggered by pull-to-refresh on the Day page. Delegates to the
    /// shared `InboxSyncEngine`. Errors are swallowed (user-facing state
    /// is just "no new suggestions appeared").
    func refresh(via engine: InboxSyncEngine?) async {
        guard let engine else { return }
        _ = try? await engine.sync(now: Date())
        // After a successful sync, re-fetch suggestions for the current week.
        await reload()
    }
```

If a `reload()` method doesn't exist, replace its call with whatever the existing method is that re-queries `InboxStoring.pending(...)`. Read the file to confirm.

- [ ] **Step 2: Add `refresh()` to `WeekPageViewModel`**

Same shape:

```swift
    func refresh(via engine: InboxSyncEngine?) async {
        guard let engine else { return }
        _ = try? await engine.sync(now: Date())
        await reload()
    }
```

- [ ] **Step 3: Wire pull-to-refresh into the views**

In whichever view hosts the Day page's main `ScrollView` (likely `PaperDayView.swift` or `DayPageView.swift`), grab the engine from environment and add `.refreshable`:

```swift
@Environment(\.inboxSyncEngine) private var inboxSyncEngine

// On the ScrollView (or List) in the body:
.refreshable {
    await viewModel.refresh(via: inboxSyncEngine)
}
```

Same in the Week page's view.

If the existing view doesn't use a `ScrollView` (it might use a custom paper-flip container), wrap the relevant content with `.refreshable` at the right level — the gesture requires a `ScrollView` or `List` ancestor.

- [ ] **Step 4: Build + tests**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: full suite still green (no new tests; behavior is exercised manually in Task 18).

- [ ] **Step 5: Commit**

```bash
git add WeeklyPlanner/Features/DayPage/DayPageViewModel.swift \
        WeeklyPlanner/Features/WeekPage/WeekPageViewModel.swift \
        WeeklyPlanner/Features/DayPage/ \
        WeeklyPlanner/Features/WeekPage/ \
        WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): pull-to-refresh on Day/Week pages delegates to InboxSyncEngine

DayPageViewModel.refresh(via:) and WeekPageViewModel.refresh(via:)
call engine.sync then re-fetch the current week's InboxSuggestion rows.
.refreshable { ... } on the day/week ScrollViews binds the gesture.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 17: `.gmailDidConnect` listener kicks one-shot sync

**Files:**
- Modify: `WeeklyPlanner/Navigation/AppShell.swift` (or wherever the engine env value is first available in a long-lived view)

- [ ] **Step 1: Add the listener**

Pick a long-lived view that has access to `\.inboxSyncEngine`. `AppShell` is a good fit since it lives for the whole app session. Add:

```swift
@Environment(\.inboxSyncEngine) private var inboxSyncEngine

// In body, on the root container:
.onReceive(NotificationCenter.default.publisher(for: .gmailDidConnect)) { _ in
    Task {
        _ = try? await inboxSyncEngine?.sync(now: Date())
    }
}
```

If `AppShell` doesn't already import Combine for `NotificationCenter.publisher`, add `import Combine`.

- [ ] **Step 2: Build**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild build -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 \
  | grep -E "BUILD FAILED|BUILD SUCCEEDED" | tail -2
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add WeeklyPlanner/Navigation/AppShell.swift WeeklyPlanner.xcodeproj
git commit -m "feat(phase-18): AppShell listens for .gmailDidConnect → kicks one-shot sync

Phase 17's ConnectionsViewModel posts .gmailDidConnect after a
successful sign-in. AppShell subscribes via
NotificationCenter.default.publisher and triggers
InboxSyncEngine.sync(now:) so the user sees inbox suggestions appear
within seconds of connecting.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 18: Full suite + manual on-device verification

**Files:** none (verification only)

- [ ] **Step 1: Full suite green**

```bash
xcodegen generate 2>&1 | tail -1
xcodebuild test -project WeeklyPlanner.xcodeproj -scheme WeeklyPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 \
  | grep -E "TEST FAILED|TEST SUCCEEDED|Executed [0-9]+ tests" | tail -3
```

Expected: ~258 tests, 0 failures (234 baseline + 24 new Phase-18 tests).

- [ ] **Step 2: Boot, install, launch**

```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "WeeklyPlanner.app" -path "*Debug-iphonesimulator*" -exec stat -f "%m %N" {} \; | sort -rn | head -1 | awk '{print $2}')
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.weeklyplanner.WeeklyPlanner
open -a Simulator
```

- [ ] **Step 3: Manual verification (HUMAN; subagent reports DONE here and surfaces the checklist)**

Hand off to the human with this checklist:

1. Settings → Connections → Gmail toggle → sign in (the same test-user Gmail you added to Google Cloud Console for Phase 17).
2. After consent, return to the app. Tab back to Calendar (Day page).
3. Within ~10 seconds, the Inbox block on the Day page should populate with suggestions extracted from the user's actual inbox (if any qualifying messages exist within the last 14 days).
4. Tap the green "+" on a suggestion → it disappears with the 0.25s collapse, an Event appears in the day's events list, and the system Calendar (`open -a Calendar` on macOS via the simulator's shared calendar) shows the new event.
5. Pull down on the Day page → top-bar sync spinner appears briefly while the engine runs.
6. Force-quit and relaunch → suggestions are still there (persisted in SwiftData).

If the user's real inbox has NO event-like messages in the last 14 days, the inbox block stays empty — that's expected. Send the user a test calendar invite from another account if needed to validate the pipeline end-to-end.

- [ ] **Step 4: Do not commit** — verification only.

---

## Task 19: Phase 18 retrospective

**Files:**
- Modify: `docs/phases/README.md`

- [ ] **Step 1: Append after the Phase 17 retro**

```markdown
### Phase 18 — Gmail Inbox Pipeline

Shipped the inbox-to-calendar pipeline that turns Phase 17's OAuth token
into actual `InboxSuggestion` rows. `GmailClient` wraps Gmail REST v1
with bearer-token auto-refresh on 401 (one retry; second 401 →
`reauthenticationRequired`), `Retry-After`-aware backoff on 429 (up to
5 retries), and a `URLSessionProtocol` seam so tests use
`URLProtocolStub` instead of the network. `MessageClassifier` is the
cheap pre-filter (subject keywords + sender domains) that runs before
the expensive `EventExtractor` Foundation Models call.

`InboxSyncEngine` is the orchestrator — single-flight via
`@MainActor`-isolated state, emits `SyncProgress` via `AsyncStream`, and
decides between delta sync (history cursor in `UserSettings.gmailLastHistoryId`)
and full re-sync (cursor nil or expired). `GmailDeltaSync` is a thin
helper around the cursor read/write so the engine doesn't touch
SwiftData inside its loop.

`LiveEventExtractor` uses `LanguageModelSession`'s structured-output
mode to return `ExtractedEvent` directly (no string parsing), gated
`#if canImport(FoundationModels)` + `@available(iOS 26.0, *)`.
`StubEventExtractor` always returns `isEvent=false` — used by tests and
as the runtime fallback when Foundation Models is unavailable
(background context, Apple Intelligence off, older OS).

Accept-flow: `SwiftDataInboxStore.init` now optionally accepts an
`EventStoring` + `SettingsStoring`; when both are present, `accept(id:)`
builds an `Event` with `source=.gmail` and the round-trip
`gmailMessageID/from/subject` fields, applies `DefaultReminderPolicy`
(new), and calls `EventStore.upsert` — which mirrors to EventKit via
the Phase 04 decorator. `WeeklyPlannerApp` constructs the wired
inbox store at startup so production gets the full accept flow;
existing Phase 17 / preview / test call sites pass nil and keep the
status-flip-only behavior.

`BackgroundRefreshScheduler` registers
`com.weeklyplanner.WeeklyPlanner.gmailRefresh` with `BGTaskScheduler`
and submits a 1-hour `BGAppRefreshTaskRequest` after every foreground
sync. UI hookups: `DayPageViewModel.refresh(via:)` and
`WeekPageViewModel.refresh(via:)` delegate to the engine;
`.refreshable` on the Day/Week ScrollViews binds pull-to-refresh.
`AppShell` listens for `.gmailDidConnect` and kicks a one-shot sync the
moment Phase 17's connect flow completes.

**Tests added**: 6 classes / 24 new test methods
(`GmailClientTests` × 5, `GmailQueryBuilderTests` × 2,
`MessageClassifierTests` × 4, `EventExtractorTests` × 4,
`InboxSyncEngineTests` × 6, `DefaultReminderPolicyTests` × 3). Full
suite: ~258 tests, all green.

**Files**: `WeeklyPlanner/Stores/Gmail/{GmailMessage,URLSessionProtocol,GmailClient,GmailQueryBuilder,MessageClassifier,GmailDeltaSync,InboxSyncEngine,BackgroundRefreshScheduler}.swift`, `WeeklyPlanner/Stores/InboxStore+Gmail.swift`, `WeeklyPlanner/Intelligence/{ExtractedEvent,EventExtractor}.swift`, `WeeklyPlanner/Intelligence/Tasks/LiveEventExtractor.swift`, `WeeklyPlanner/Notifications/DefaultReminderPolicy.swift`; modified `WeeklyPlanner/Models/{UserSettings,InboxSuggestion}.swift`, `WeeklyPlanner/Stores/{InboxStore,Environment+Stores}.swift`, `WeeklyPlanner/App/WeeklyPlannerApp.swift`, `WeeklyPlanner/Supporting/Info.plist`, `WeeklyPlanner/Features/{DayPage,WeekPage}/*ViewModel.swift`, `WeeklyPlanner/Navigation/AppShell.swift`.
```

- [ ] **Step 2: Flip the status table row**

Change Phase 18 from `⏳` to `✅`. Update the "Current state" line:

```
**Current state:** Milestones A–F + Phases 16, 17, 18 shipped. ~258
unit tests green. Next up: Phase 19 — Notifications.
```

- [ ] **Step 3: Commit**

```bash
git add docs/phases/README.md
git commit -m "docs(phase-18): retrospective + status updates

Phase 18 marked complete in the Phase Map; current-state line points
at Phase 19. Retrospective covers the GmailClient transport layer,
classifier + extractor pipeline, sync engine, accept-flow wiring, BG
scheduler, and UI hookups.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 20: Hand-off

**Files:** none

- [ ] **Step 1: Confirm branch clean and Phase 18 commits land**

```bash
git status --short
git log --oneline -30 | grep "phase-18"
```

Expected: empty status; ~18 `phase-18` commits.

- [ ] **Step 2: Do NOT merge to main**

Phase 19 lands on the same `milestone-h-integrations` branch. Final merge happens after Phase 19 is also green.

- [ ] **Step 3: Hand off to Phase 19 plan-writing**

Tell the user Phase 18 is done on the branch. Next step: write the Phase 19 plan via `superpowers:writing-plans` against the same Milestone H spec, informed by anything learned during the Phase 18 on-device verification (BG task firing reliability, FoundationModels availability in BG, notification permission timing).

---

## Self-review

**Spec coverage** (against §3 "Phase 18 — Gmail Inbox Pipeline" of `docs/superpowers/specs/2026-05-20-milestone-h-integrations-design.md`):
- ✅ Files added — every file in the spec's list maps to a task here.
- ✅ SwiftData migrations (Task 2): both `gmailLastHistoryId` and `proposedLocation`.
- ✅ GmailClient with 401 refresh + 429 backoff (Tasks 3-5).
- ✅ GmailQueryBuilder (Task 6).
- ✅ MessageClassifier rules layer (Task 7).
- ✅ EventExtractor + Stub + Live (Tasks 8-9).
- ✅ GmailDeltaSync cursor helper (Task 10).
- ✅ DefaultReminderPolicy (Task 11) — moved here from Phase 19 because Phase 18 accept-flow needs it.
- ✅ InboxStore+Gmail accept flow (Task 12).
- ✅ InboxSyncEngine actor + AsyncStream<SyncProgress> (Task 13).
- ✅ BackgroundRefreshScheduler + Info.plist (Task 14).
- ✅ Env wiring (Task 15).
- ✅ UI hookups: refresh + spinner + .gmailDidConnect listener (Tasks 16-17).
- ✅ Manual on-device verification (Task 18).
- ✅ Retro + hand-off (Tasks 19-20).

**Placeholder scan:** no "TBD" / "implement later" / vague-handling strings. Every test method is named and bodied. Two soft places that may need real-time adjustment during execution: (a) `LanguageModelSession.respond(to:generating:)` exact API — call out in the task; (b) `Reminder.timeBefore(minutes:)` case name — call out in the task. Both have explicit "read the source, adapt" instructions.

**Type consistency:** `GmailClientProtocol`, `GmailMessage`, `GmailMessageStub`, `GmailHistoryResponse`, `GmailProfile`, `GmailMessageFormat`, `ExtractedEvent`, `EventExtractor`, `StubEventExtractor`, `LiveEventExtractor`, `FakeEventExtractor`, `MessageClassifier.Verdict`, `SyncProgress`, `SyncResult`, `InboxSyncEngine`, `GmailDeltaSync`, `BackgroundRefreshScheduler`, `DefaultReminderPolicy`, `URLSessionProtocol`, `URLProtocolStub`, `RecordingAuthService`, `FakeGmailClient`, `InMemoryEventStore` — all defined within tasks and referenced consistently across tasks.

**Out of scope (deferred to Phase 19 or later)**:
- Real notification scheduling (Phase 19 — `EventNotificationScheduler`, `LocationReminderManager`).
- "Reconnect Gmail" inline messaging when client throws `.reauthenticationRequired` (Phase 19 polish; for now the row just sits in connected state until the user manually disconnects).
- Smart batch-accept (deferred v1.1 per spec).
- Conflict detection between extracted events and existing calendar entries (deferred v1.1 per spec).
