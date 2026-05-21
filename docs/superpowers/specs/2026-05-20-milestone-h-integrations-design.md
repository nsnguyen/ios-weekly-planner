# Milestone H — Integrations (Phases 17 → 18 → 19)

**Status:** Design approved · ready for implementation plan
**Branch:** `milestone-h-integrations` (off `main`)
**Phases bundled:** 17 (Settings — Connections), 18 (Gmail Inbox Pipeline), 19 (Notifications)
**Phase 17 is a hard prerequisite for 18** — bundling the three avoids two design/plan cycles and keeps the OAuth → fetch → notify story coherent end-to-end.

---

## 1. Scope & shape

### What ships

One branch, three commit clusters in order:
1. **Phase 17** — real GoogleSignIn OAuth, Keychain token storage, `ConnectionsSection` replacing the Phase 16 placeholder.
2. **Phase 18** — Gmail REST client, classifier + Foundation-Models event extractor, sync engine, BG refresh, accept-flow that writes through to EventKit.
3. **Phase 19** — `UNUserNotificationCenter` wrapper, event + task schedulers, location-based reminders via `CLCircularRegion`, actionable categories, deep-link routing on tap.

Final merge commit:
`Merge branch 'milestone-h-integrations' (Phase 17 — Connections; Phase 18 — Gmail pipeline; Phase 19 — Notifications)`

### What does not ship

Carried forward as-stated in the source phase docs:
- Google Calendar two-way sync (defer v1.1)
- Apple Mail message scanning / MailKit extension (requires MDM entitlement)
- Outlook / Microsoft 365
- Smart batch-accept (“Accept all 3”)
- Conflict detection between proposed and existing events
- Rich notifications with images
- Apple Watch handoff (works out-of-box via mirror)
- “Snooze 1h” / smart-snooze
- Localization of subject-keyword rules (Phase 21)
- Snapshot tests for the new Settings card (Phase 21)

### Milestone-level acceptance

1. Toggling Gmail in Settings opens the real OAuth sheet, persists tokens in Keychain, account email shows in the row.
2. Within ~10s of connect (and on every pull-to-refresh / hourly BG tick), Resy/Ticketmaster-style emails produce `InboxSuggestion` rows on the Day page.
3. Accepting a suggestion writes an `Event`, mirrors to EventKit, vanishes from the inbox block with the 0.25s collapse.
4. New events get a `defaultReminderMinutes` `Reminder` applied; the iOS notification actually fires at `start − N min` on a physical device.
5. Toggling **When I arrive** on the event sheet registers a `CLCircularRegion` and fires on simulated location entry.
6. Denied notifications path shows the in-Settings banner; granting later schedules forward via `rescheduleAll()`.

### Test budget

Full unit suite stays green at every commit. Target adds: ~60–80 unit tests (Phase 17 ~15, Phase 18 ~30, Phase 19 ~20). No new XCUITest unless a flow can't be exercised at the unit level.

---

## 2. Phase 17 — Settings → Connections (OAuth foundation)

### Files added / modified

```
WeeklyPlanner/Auth/GoogleAuth/
  GoogleAuthConfig.swift              # reads $(GOOGLE_CLIENT_ID) from Info.plist at runtime
  GoogleAuthService.swift             # protocol + LiveGoogleAuthService + StubGoogleAuthService
  TokenKeychainStore.swift            # KeychainAccess wrapper, generic over Codable
  GoogleAccountInfo.swift             # { email, accessToken, refreshToken, expiresAt }
WeeklyPlanner/Features/Settings/
  ConnectionsSection.swift            # replaces ConnectionsPlaceholder body
  ConnectionRow.swift
  ConnectionsViewModel.swift          # @Observable; owns sign-in / sign-out side effects
  Logos/GmailBrandLogo.swift          # 22×16 multi-color SF Symbol-free SwiftUI
  Logos/AppleBrandLogo.swift          # 18×22 mono
  Logos/GoogleCalLogo.swift           # 20×20 stylized "31"
WeeklyPlanner/Stores/Environment+Stores.swift  # MODIFY — add \.googleAuthService env key
Secrets.example.xcconfig              # committed, empty values, documents the contract
Secrets.xcconfig                      # GITIGNORED, holds the real client ID
.gitignore                            # MODIFY — add Secrets.xcconfig
project.yml                           # MODIFY — packages: GoogleSignIn-iOS; configFiles; INFOPLIST_KEY hookup
WeeklyPlanner/Supporting/Info.plist   # MODIFY — CFBundleURLSchemes uses $(REVERSED_GOOGLE_CLIENT_ID)
README.md                             # MODIFY — “Google OAuth setup” section
WeeklyPlannerTests/Auth/GoogleAuthServiceTests.swift
WeeklyPlannerTests/Features/ConnectionsSectionTests.swift
WeeklyPlannerTests/Features/ConnectionsViewModelTests.swift
```

Snapshot tests are deferred (consistent with Phase 16).

### Secret plumbing (XcodeGen → xcconfig → Info.plist)

`Secrets.example.xcconfig` (committed):
```
GOOGLE_CLIENT_ID =
REVERSED_GOOGLE_CLIENT_ID =
```

`Secrets.xcconfig` (gitignored, user fills in once):
```
GOOGLE_CLIENT_ID = 436650706844-9nonlbksnaal4io6cldhkrf7qkgf23gk.apps.googleusercontent.com
REVERSED_GOOGLE_CLIENT_ID = com.googleusercontent.apps.436650706844-9nonlbksnaal4io6cldhkrf7qkgf23gk
```

`project.yml` additions:
- `configFiles: { Debug: Secrets.xcconfig, Release: Secrets.xcconfig }`
- `INFOPLIST_KEY_GoogleClientID = $(GOOGLE_CLIENT_ID)`
- Existing `CFBundleURLSchemes` entry becomes `$(REVERSED_GOOGLE_CLIENT_ID)` (currently the literal `com.googleusercontent.apps.PLACEHOLDER`).

`GoogleAuthConfig` reads `Bundle.main.object(forInfoDictionaryKey: "GoogleClientID")` at init. If empty (someone forgot to fill `Secrets.xcconfig`), `LiveGoogleAuthService.signIn(...)` throws `.notConfigured` and the UI shows a one-shot alert (“Gmail isn’t configured for this build — see README.”). The runtime never crashes from a missing secret.

### `GoogleAuthService` protocol

```swift
@MainActor
protocol GoogleAuthService: AnyObject {
    func signIn(presenting: UIViewController) async throws -> GoogleAccountInfo
    func signOut() async
    func currentAccount() -> GoogleAccountInfo?
    func accessToken() async throws -> String   // refreshes if <5min remain
}
```

- `LiveGoogleAuthService` wraps `GIDSignIn.sharedInstance` from the [GoogleSignIn-iOS](https://github.com/google/GoogleSignIn-iOS) SPM dep (added to `project.yml` packages). Persists tokens in `TokenKeychainStore` keyed by `com.weeklyplanner.WeeklyPlanner.google`.
- `StubGoogleAuthService` returns a canned `GoogleAccountInfo` for tests / previews / `ConnectionsViewModelTests`.
- Injected via `@Environment(\.googleAuthService)` matching the existing store pattern in `Environment+Stores.swift`.
- Errors: `.notConfigured`, `.userCancelled`, `.network(Error)`, `.reauthenticationRequired`.

### `TokenKeychainStore`

Generic over any `Codable`, keyed by a service-id string. Backs onto `KeychainAccess` (already in `project.yml`). Tokens persist across reinstalls by iOS default — disconnect is the only path that clears them.

### `ConnectionsSection` + `ConnectionRow`

Replaces `ConnectionsPlaceholder` verbatim per the Phase 17 phase doc (Visual & Interaction Checklist). Three rows separated by 0.5pt `theme.rule`, no divider after the last. Each row: logo (28pt container) · label + detail · 44×26 `PaperToggle`.

Row contents:
- **Gmail** — logo, “Gmail”, detail `"{email} · syncing events"` when on / `"Tap to connect — pulls events & reminders from your inbox"` when off. Toggle off→on triggers OAuth; on→off shows destructive confirmation.
- **Apple Mail** — logo, “Apple Mail”, detail `"Connected · iCloud"` if `MFMailComposeViewController.canSendMail()` else `"Sign in to Mail in iOS Settings"`. Toggle always on, disabled; tap shows tooltip alert.
- **Google Calendar** — logo, “Google Calendar”, detail `"Coming soon"`. Toggle off, disabled.

### `ConnectionsViewModel`

`@Observable`. Owns the connect/disconnect choreography so the SwiftUI view stays declarative:
- `connectGmail()`: optimistic flip → `GoogleAuthService.signIn(presenting:)` (presenter resolved via `UIApplication.shared.connectedScenes`) → on success `SettingsStoring.update(gmailConnected: true, gmailAccountEmail: email)` + post a `Notification.Name.gmailDidConnect` for Phase 18 to listen and kick a one-shot sync → on failure revert + transient alert.
- `disconnectGmail()`: confirmation alert → `signOut()` + clear Keychain + `SettingsStoring.update(gmailConnected: false, gmailAccountEmail: nil)` + cascade-delete `InboxSuggestion` rows where `status == .pending`.

### App-side OAuth handling

`WeeklyPlannerApp` adds `.onOpenURL { GIDSignIn.sharedInstance.handle($0) }`. No `UIApplicationDelegateAdaptor` needed for Phase 17 (we add one in Phase 19 for notifications).

### Phase 17 tests (TDD)

`GoogleAuthServiceTests` — wraps `GIDSignIn` behind an internal `GIDSigningClient` protocol so we can fake it:
- `testSignInPersistsTokensInKeychain()`
- `testSignInFailurePropagates()`
- `testSignOutClearsKeychain()`
- `testAccessTokenRefreshesWhenExpiringSoon()`
- `testNotConfiguredErrorWhenClientIDEmpty()`

`ConnectionsViewModelTests` — fake `GoogleAuthService` + in-memory `SwiftDataSettingsStore` + `SwiftDataInboxStore`:
- `testConnectGmailHappyPathSetsConnectedFlag()`
- `testConnectGmailCancelRevertsFlag()`
- `testDisconnectClearsTokensAndPendingSuggestions()`

`ConnectionsSectionTests` — `ViewInspector` not currently a dep; assert structural invariants only (rows count, toggle disabled-state matrix) consistent with `PaperSettingsViewTests` from Phase 16.

---

## 3. Phase 18 — Gmail Inbox Pipeline

### Files added / modified

```
WeeklyPlanner/Stores/Gmail/
  GmailClient.swift                   # URLSession + auto-refresh on 401
  GmailMessage.swift                  # DTOs (message, header, payload, history)
  GmailQueryBuilder.swift             # the q= filter from the phase doc
  GmailDeltaSync.swift                # historyId-driven incremental sync
  MessageClassifier.swift             # rules layer (subject + sender)
  InboxSyncEngine.swift               # orchestrator, actor, AsyncStream<SyncProgress>
  BackgroundRefreshScheduler.swift    # BGAppRefreshTask wrapper
WeeklyPlanner/Intelligence/Tasks/
  EventExtractor.swift                # FoundationModels structured-output prompt
WeeklyPlanner/Stores/
  InboxStore+Gmail.swift              # MODIFY accept(id:) → builds Event + EventStore.upsert
  Environment+Stores.swift            # MODIFY — \.gmailClient, \.inboxSyncEngine env keys
WeeklyPlanner/Models/UserSettings.swift     # MODIFY — add gmailLastHistoryId: String?
WeeklyPlanner/Models/InboxSuggestion.swift  # MODIFY — add proposedLocation: String?
# Event.swift unchanged — source/gmailMessageID/gmailFrom/gmailSubject already exist (verified)
WeeklyPlanner/Features/DayPage/DayPageViewModel.swift   # MODIFY — refresh() delegates to sync
WeeklyPlanner/Features/WeekPage/WeekPageViewModel.swift # MODIFY — refresh() delegates to sync
WeeklyPlanner/Navigation/AppShell.swift # MODIFY — top-bar sync spinner
WeeklyPlanner/App/WeeklyPlannerApp.swift # MODIFY — register BGTask identifier on launch
WeeklyPlanner/Supporting/Info.plist     # MODIFY — BGTaskSchedulerPermittedIdentifiers entry
WeeklyPlannerTests/Gmail/GmailClientTests.swift
WeeklyPlannerTests/Gmail/MessageClassifierTests.swift
WeeklyPlannerTests/Gmail/EventExtractorTests.swift
WeeklyPlannerTests/Gmail/InboxSyncEngineTests.swift
```

### SwiftData migrations

Two field adds, both nullable so the migration stays lightweight (no schema version bump):

- `UserSettings.gmailLastHistoryId: String?` — delta-sync cursor.
- `InboxSuggestion.proposedLocation: String?` — populated by `EventExtractor` so the accept-flow can carry it through to `Event.location` without a second lookup.

### `GmailClient`

Constructor takes a `GoogleAuthService` and a `URLSession` (injectable for tests via `URLProtocol` stubs). Endpoints:
- `listMessages(query: String, maxResults: Int) async throws -> [GmailMessageStub]`
- `fetchMessage(id: String, format: GmailFormat) async throws -> GmailMessage`
- `history(startHistoryId: String) async throws -> GmailHistoryResponse`
- `profile() async throws -> GmailProfile`

Behaviour:
- On `401`, ask `GoogleAuthService.accessToken()` to refresh, retry once.
- On second `401`, throw `.reauthenticationRequired` so the UI can flip `gmailConnected=false` and surface inline “Reconnect Gmail”.
- On `429`, honour `Retry-After`; exponential backoff up to 5 retries with jitter.

### `GmailQueryBuilder`

Single default query for v1.0 (per phase doc):
```
(from:reservations OR from:tickets OR from:noreply OR from:reception
 OR subject:(invite|confirmation|reservation|ticket|appointment))
 -category:promotions -category:social
 newer_than:14d
```

User customisation is deferred to v1.1.

### `MessageClassifier`

Pure-Swift, no I/O. Inputs: subject, from-email, from-name. Output: `(passes: Bool, ruleHits: [String])`.
- Subject keywords: `appointment`, `confirmed`, `ticket`, `reservation`, `invite`, `RSVP`, `booking`.
- Sender domains: `resy.com`, `opentable.com`, `ticketmaster.com`, `eventbrite.com`, `airbnb.com`, plus any sender whose name contains “calendar”.
- Returns `passes: false` for known noise domains (`unsubscribe`, `newsletter`, `marketing`).

The classifier is the cheap gate. Only when `passes == true` does the pipeline hand the message to `EventExtractor`.

### `EventExtractor` (Foundation Models)

```swift
struct ExtractedEvent: Codable {
    let isEvent: Bool
    let title: String?
    let startISO: String?
    let endISO: String?
    let location: String?
    let categoryHint: String?
    let confidence: Double      // 0…1
}
```

- Uses `LanguageModelSession.respond(to:as:)` with `ExtractedEvent.self` (structured output).
- Gated `#if canImport(FoundationModels)` + `@available(iOS 26.0, *)`.
- `StubEventExtractor` always returns `isEvent: false` — used by tests, previews, and as the BG fallback when Foundation Models is unavailable.
- System prompt: `"Extract a single calendar event from this email. If no event is present, return isEvent=false. Never invent details — leave fields nil if missing."`
- Input: subject + first 3000 chars of body + from name/email.

### `InboxSyncEngine`

Modeled as an `actor` to enforce single-flight (queued follow-up if `sync(now:)` is called during sync):
```swift
actor InboxSyncEngine {
    func sync(now: Date) async throws -> SyncResult
    var progress: AsyncStream<SyncProgress>
}
```
Pipeline per call:
1. `GoogleAuthService.accessToken()` (refresh if needed).
2. Read `UserSettings.gmailLastHistoryId`; if present try `history?startHistoryId=`; on `404` (history expired) full re-sync via the default query.
3. For each new message: `GmailClient.fetchMessage(format: .full)` → `MessageClassifier.classify` → if pass, `EventExtractor.extract` → if `isEvent && confidence ≥ 0.55 && proposedStart > now`, upsert `InboxSuggestion` keyed by `gmailMessageID`.
4. Persist new `historyId` from `GmailClient.profile()`.
5. Schedule next BG refresh.

Failures are non-fatal — the engine logs (`os_log` `.private` for any subject/body), updates a per-run `SyncResult.errors`, and proceeds.

### `BackgroundRefreshScheduler`

- Identifier: `com.weeklyplanner.WeeklyPlanner.gmailRefresh`.
- Registered in `WeeklyPlannerApp.init` via `BGTaskScheduler.shared.register(forTaskWithIdentifier:using:launchHandler:)`.
- Submitted at the end of each foreground sync with `earliestBeginDate = now + 1h`.
- Inside the BG handler: token is refreshed only if `<5min` remaining (BG budget is tiny); if `Availability` reports Foundation Models unavailable, fall back to rules-only (`StubEventExtractor`).
- `Info.plist`: add to `BGTaskSchedulerPermittedIdentifiers` array.

### Accept / dismiss

`InboxStore+Gmail.swift` augments the existing `accept(id:)`. `InboxSuggestion` gains a `proposedLocation: String?` field (populated by `EventExtractor` when present) so the accept-flow can pass it through without a second model lookup. Lightweight SwiftData migration alongside `gmailLastHistoryId`:

```swift
func accept(id: UUID) async throws {
    guard let s = try await suggestion(id: id) else { return }
    let event = Event(
        title: s.title,
        start: s.proposedStart,
        end: s.proposedEnd ?? s.proposedStart.addingTimeInterval(3600),
        location: s.proposedLocation,
        category: s.category,
        source: .gmail,
        gmailMessageID: s.gmailMessageID,
        gmailFrom: s.fromEmail,
        gmailSubject: s.subject
    )
    DefaultReminderPolicy.apply(to: event, settings: settingsStore.current())   // mutates reminders via class reference
    try await eventStore.upsert(event)   // mirrors to EventKit via Phase 04 decorator
    s.status = .accepted
    try context.save()
}
```

`Event` is a `@Model final class`, so `DefaultReminderPolicy.apply(to:settings:)` takes the reference (no `inout` needed) and mutates `event.reminders` directly.
`dismiss(id:)` unchanged from current; once dismissed, the engine skips that `gmailMessageID` on subsequent syncs (predicate filter).

### UI hookups

- `DayPageViewModel.refresh()` and `WeekPageViewModel.refresh()` delegate to `InboxSyncEngine.sync(now:)`.
- Pull-to-refresh on Day + Week pages wired to those.
- `AppShell` watches `InboxSyncEngine.progress` and renders a 6pt ink dot in the top-bar trailing area while progress is emitting.
- `Notification.Name.gmailDidConnect` triggers a one-shot sync immediately after Phase 17’s connect succeeds.

### Risks

- **Token refresh in BG can blow the budget** — cache aggressively, only refresh when <5min remain.
- **Foundation Models unavailable in BG** — official guidance is “may not be available outside foreground”; pipeline degrades to rules-only via `StubEventExtractor`.
- **PII** — never log raw email bodies; `os_log` with `.private` everywhere subject/body touch a log call.
- **Gmail quota** — 250 quota units/sec per user, full-format message read = 5 units; plenty for `maxResults=50` per sync.

### Phase 18 tests (TDD)

`GmailClientTests` (URLProtocol-stubbed URLSession):
- `testListMessagesEncodesQuery()`
- `testFetchMessageRetriesOn429WithRetryAfter()`
- `testRefreshOn401AndRetryOnce()`
- `testSecondaryConsecutive401ThrowsReauth()`
- `testHistory404TriggersFullResyncPath()`

`MessageClassifierTests` (pure):
- `testResyConfirmationSenderPasses()`
- `testTicketmasterSubjectKeywordPasses()`
- `testPromotionalNewsletterFails()`
- `testGenericTransactionalEmailPassesToAIGate()`

`EventExtractorTests` (mocked `LanguageModelSession`):
- `testResyConfirmationExtractsTitleAndStart()`
- `testAmbiguousEmailReturnsIsEventFalse()`
- `testMissingTimeReturnsNilStart()`
- `testStubExtractorAlwaysReturnsFalse()`

`InboxSyncEngineTests` (fake `GmailClient` + fake `EventExtractor` + in-memory `SwiftDataInboxStore`/`SwiftDataEventStore`):
- `testInitialFullSyncInsertsSuggestions()`
- `testDeltaSyncOnlyProcessesNewMessages()`
- `testAcceptCreatesEventAndMirrorsToEventKit()`
- `testDismissPreventsResuggestionOnNextSync()`
- `testPastDatedSuggestionSkipped()`
- `testSingleFlightQueuesSecondCall()`

---

## 4. Phase 19 — Notifications

### Files added / modified

```
WeeklyPlanner/Notifications/
  NotificationCenter.swift              # internal protocol wrapping UNUserNotificationCenter
  NotificationAuthorization.swift       # request + status, .timeSensitive opt-in
  EventNotificationScheduler.swift
  TaskNotificationScheduler.swift
  LocationReminderManager.swift         # CLLocationManager + 20-region priority queue
  NotificationContentBuilder.swift      # localized title/subtitle/body
  NotificationCategoryIDs.swift         # eventCategory + taskCategory + actions
  AppDelegate+Notifications.swift       # UIApplicationDelegateAdaptor route handler
  DefaultReminderPolicy.swift           # apply(to: Event, settings:) — called by Phase 18 accept + future manual-add
WeeklyPlanner/App/WeeklyPlannerApp.swift # MODIFY — @UIApplicationDelegateAdaptor
WeeklyPlanner/Navigation/AppShell.swift  # MODIFY — pendingDeepLink @Environment + sheet routing
WeeklyPlanner/Features/Settings/ConnectionsSection.swift # MODIFY — denied-notifications banner
WeeklyPlanner/Supporting/WeeklyPlanner.entitlements      # MODIFY — com.apple.developer.usernotifications.time-sensitive
WeeklyPlanner/Supporting/Info.plist     # already has NSLocationWhenInUseUsageDescription + NSUserNotificationsUsageDescription
WeeklyPlannerTests/Notifications/EventNotificationSchedulerTests.swift
WeeklyPlannerTests/Notifications/TaskNotificationSchedulerTests.swift
WeeklyPlannerTests/Notifications/LocationReminderManagerTests.swift
WeeklyPlannerTests/Notifications/NotificationContentBuilderTests.swift
WeeklyPlannerTests/Notifications/DefaultReminderPolicyTests.swift
```

### `NotificationCenter` (internal protocol)

```swift
@MainActor
protocol NotificationCentering: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func pendingRequests() async -> [UNNotificationRequest]
    func removePending(withIdentifiers: [String])
}
```
`LiveNotificationCenter` wraps `UNUserNotificationCenter.current()`. `FakeNotificationCenter` is the test fake.

### `EventNotificationScheduler`

```swift
func schedule(event: Event) async throws
func cancel(eventID: UUID) async
func rescheduleAll(in window: ClosedRange<Date>) async   // window defaults to next 30 days
```
- Stable request identifiers: `"event-{uuid}-time-{minutes}"`, `"event-{uuid}-arrive"`.
- Before scheduling, `cancel(eventID:)` to clear any stale requests for that event.
- Calendar trigger for each `Reminder.timeBefore(minutes:)`; location trigger for each `Reminder.onArrive(location:)` (delegates region registration to `LocationReminderManager`).
- Sets `interruptionLevel = .timeSensitive` when the entitlement is granted.

### `TaskNotificationScheduler`

Mirror of the event shape for `TaskItem.reminderTime` (calendar trigger at exact time) and `TaskItem.locationReminder` (matches `data.jsx` t3 “When I arrive at Marina”).

### `LocationReminderManager`

- Holds the singleton `CLLocationManager`.
- Tracks up to 20 active regions (iOS hard limit).
- Priority queue: today’s events first, then next-24h, then next-7d. Re-evaluates on every event save and on day rollover.
- Permission: `requestWhenInUseAuthorization` on first onArrive toggle; escalate to `requestAlwaysAuthorization` (better wake-from-killed reliability) only when the user enables onArrive on an event >24h out. Soft-ask explanation card before the system prompt.
- On region entry → builds and dispatches a `UNNotificationRequest` via `NotificationCenter.add(_:)`.

### `NotificationContentBuilder`

- `String(localized:)` for every user-facing string (Phase 21 fills the catalog).
- Title: event title; truncated to 64 chars with “…”.
- Subtitle: `"{time} · {location}"` if location present, else just `{time}`.
- Body: `"In {n} minutes."` for time-based, `"You've arrived at {location}."` for arrival.

### `NotificationCategoryIDs`

```
eventCategory  → [viewEvent, snooze10]
taskCategory   → [viewTask, markDone]
```
Registered once in `WeeklyPlannerApp.init`.

### `AppDelegate+Notifications`

- `UIApplicationDelegateAdaptor` added to `WeeklyPlannerApp`.
- `application(_:didFinishLaunchingWithOptions:)` stays lightweight (no SwiftData touches) so location-wake launches are cheap.
- On cold-launch with payload, parse `event.id` / `task.id` from `userInfo` and write into a `PendingDeepLink` observable.
- `userNotificationCenter(_:didReceive:withCompletionHandler:)` handles actions:
  - `viewEvent` / `viewTask` → set `PendingDeepLink` → `AppShell` presents the matching sheet.
  - `snooze10` → schedule a new request 10 min from now with identical content.
  - `markDone` → `TaskStoring.toggle(id:)` + remove the request.

### `DefaultReminderPolicy`

```swift
enum DefaultReminderPolicy {
    /// Mutates `event.reminders` via the class reference. No-op when the user
    /// has chosen "No reminder" (settings.defaultReminderMinutes == nil) or
    /// when a time-based reminder is already attached.
    static func apply(to event: Event, settings: UserSettings) {
        guard let minutes = settings.defaultReminderMinutes else { return }
        guard event.reminders.contains(where: { $0.isTimeBased }) == false else { return }
        event.reminders.append(.timeBefore(minutes: minutes))
    }
}
```
- Called by Phase 18 `accept(id:)`.
- Called by future manual-add flow.
- Existing events untouched when the user changes the default — matches spec.

### Re-scheduling triggers

- After any `EventStore.upsert` / `delete` → `EventNotificationScheduler.schedule` / `.cancel`.
- After `NotificationAuthorization.request()` grant → `rescheduleAll(in: now…now+30d)`.
- After `UserSettings.defaultReminderMinutes` change → nothing (only applies to future events).

### Risks

- **20-region cap** is per app; priority queue keyed by proximity-in-time is the riskiest piece — gets the most unit-test coverage.
- **`.timeSensitive` requires entitlement** — added in this PR.
- **Cold-launch from region entry** — keep `application(_:didFinishLaunchingWithOptions:)` SwiftData-free.
- **App Store reviewer** will test “When I arrive” — provide notes in App Store Connect (Phase 23) referencing simulator location override.
- **Per-notification mute drift** — user can mute individual notifications in iOS Settings; not detectable; documented.

### Phase 19 tests (TDD)

`EventNotificationSchedulerTests` (fake `NotificationCentering`):
- `testScheduleTimeReminderProducesCalendarRequest()`
- `testScheduleArrivalRegistersRegionAndLocationRequest()`
- `testRescheduleClearsOldRequestsByPrefix()`
- `testCancelByEventIDRemovesAllRequests()`
- `testInterruptionLevelTimeSensitiveAppliedWhenEntitled()`

`TaskNotificationSchedulerTests`: mirror of the above for tasks.

`LocationReminderManagerTests` (fake CLLocationManager):
- `testRegisterUpTo20Regions()`
- `testPriorityQueueKeepsTodayEventsActive()`
- `testRegionEntryFiresNotification()`
- `testEscalateToAlwaysAuthOnFarFutureEvent()`

`NotificationContentBuilderTests`:
- `testTitleTruncatedAt64Chars()`
- `testTimeBasedBodyTextLocalized()`
- `testLocationBasedBodyTextLocalized()`

`DefaultReminderPolicyTests`:
- `testAppliesDefaultWhenNoReminders()`
- `testNoOpWhenDefaultIsNil()`
- `testNoOpWhenEventAlreadyHasTimeReminder()`

---

## 5. Cross-cutting plumbing

### SPM dependencies

Phase 17 adds to `project.yml`:
```
GoogleSignIn-iOS:
  url: https://github.com/google/GoogleSignIn-iOS
  from: "7.1.0"
```
Target gains `dependencies: - package: GoogleSignIn-iOS, product: GoogleSignIn`.

Phase 18 needs no new SPM dep (URLSession + Foundation Models only).
Phase 19 needs no new SPM dep (UN/UN/CL/UIKit only).

### New environment keys

```swift
\.googleAuthService      // GoogleAuthService    — Phase 17
\.gmailClient            // GmailClient          — Phase 18
\.inboxSyncEngine        // InboxSyncEngine      — Phase 18
\.notificationCenter     // NotificationCentering — Phase 19
\.locationReminderManager // LocationReminderManager — Phase 19
```
Each gets a `StubXxx` impl mirroring `Environment+Stores.swift` so previews and tests don’t crash on missing env values.

### SwiftData migration summary

Single field add: `UserSettings.gmailLastHistoryId: String?`. Lightweight; no version bump.

### Entitlements summary

Added in Phase 19: `com.apple.developer.usernotifications.time-sensitive`.

### `Info.plist` summary

- Phase 17: `CFBundleURLSchemes` now uses `$(REVERSED_GOOGLE_CLIENT_ID)`.
- Phase 18: `BGTaskSchedulerPermittedIdentifiers` array containing `com.weeklyplanner.WeeklyPlanner.gmailRefresh`.
- Phase 19: no new keys (existing `NSUserNotificationsUsageDescription` + `NSLocationWhenInUseUsageDescription` cover it).

### Branch + commit hygiene

- One branch: `milestone-h-integrations`.
- Commits prefixed `feat(phase-17): …` / `feat(phase-18): …` / `feat(phase-19): …` / `test(phase-NN): …` / `fix(phase-NN): …` matching Phase 15/16 convention.
- Tests added in the same commit as the code they cover (TDD pairs).
- Each phase ends with a `docs(phase-NN): retrospective` commit appending to `docs/phases/README.md` retros section.
- Final merge: `Merge branch 'milestone-h-integrations' (Phase 17 — Connections; Phase 18 — Gmail pipeline; Phase 19 — Notifications)`.

### What I am explicitly NOT doing in this milestone

- No new mock screens / no design-spec drift from `docs/mock/`.
- No localization strings filled in (Phase 21).
- No snapshot tests for the new Settings card (Phase 21).
- No new XCUITest unless a flow can’t be exercised at the unit level.
- No Phase 22 work (App Privacy manifest, App Store reviewer notes).

---

## 6. Open follow-ups for the implementation plan

To be expanded by `superpowers:writing-plans` into a step-by-step plan:

1. Pre-Phase-17: regenerate the Xcode project after `project.yml` changes (xcodegen), confirm Secrets.xcconfig is gitignored before the first commit so the client ID never lands in history.
2. Phase 17 step ordering: secret plumbing → TokenKeychainStore + tests → GoogleAuthService protocol + stub + tests → Live impl → ConnectionsViewModel + tests → ConnectionsSection + ConnectionRow + logos → wire `\.googleAuthService` env key → `onOpenURL` handler → manual on-device verification.
3. Phase 18 step ordering: SwiftData migration field → GmailClient + tests → GmailQueryBuilder → MessageClassifier + tests → EventExtractor + StubEventExtractor + tests → InboxSyncEngine + tests → InboxStore+Gmail accept-flow → BackgroundRefreshScheduler → UI hookups (DayPageViewModel/WeekPageViewModel refresh + top-bar spinner) → wire env keys → manual on-device verification with real Gmail.
4. Phase 19 step ordering: entitlement → NotificationCentering protocol + Live + Fake → NotificationAuthorization → EventNotificationScheduler + tests → TaskNotificationScheduler + tests → LocationReminderManager + tests → NotificationContentBuilder + tests → NotificationCategoryIDs → AppDelegate routing + PendingDeepLink → DefaultReminderPolicy + tests → re-scheduling triggers wired to EventStore → manual on-device verification (time-based + arrival).
5. Final integration: end-to-end happy path on simulator (connect → sync → accept → notification fires).

---

*Approved 2026-05-20 by the user via brainstorming. Next step: `superpowers:writing-plans` to draft the implementation plan.*
