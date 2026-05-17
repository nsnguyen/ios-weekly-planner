# Phase 18 — Gmail Inbox Pipeline & Event Suggestions

## Goal
Periodically fetch the user's Gmail inbox, identify messages that look like event-related (tickets, RSVPs, confirmations), use Foundation Models to extract structured event proposals, and write them into the `InboxSuggestion` store so the Day Page (Phase 06) and Week Page (Phase 10) can surface them. Accepting a suggestion creates a real `Event` (which mirrors to EventKit via Phase 04).

## Why this is needed
This is the second pillar of "AI knows your week." Without the Gmail pipeline, the inbox suggestions area is empty.

## Prerequisites
- Phases 03 (`InboxSuggestion` model + store), 04 (EventStore writes through to EventKit), 13 (Foundation Models), 17 (Gmail OAuth).

## Files Created / Modified

```
WeeklyPlanner/Stores/Gmail/GmailClient.swift                       # NEW — REST wrapper
WeeklyPlanner/Stores/Gmail/GmailMessage.swift                      # NEW — DTOs
WeeklyPlanner/Stores/Gmail/GmailFetchService.swift                 # NEW — fetch + parse + sync
WeeklyPlanner/Stores/Gmail/GmailQueryBuilder.swift                 # NEW — query strings (event-likely senders)
WeeklyPlanner/Stores/Gmail/GmailDeltaSync.swift                    # NEW — history-based incremental sync
WeeklyPlanner/Stores/Gmail/MessageClassifier.swift                 # NEW — rules + AI gate
WeeklyPlanner/Intelligence/Tasks/EventExtractor.swift              # NEW — Foundation Models prompt
WeeklyPlanner/Stores/Gmail/InboxSyncEngine.swift                   # NEW — orchestrator
WeeklyPlanner/Stores/Gmail/BackgroundRefreshScheduler.swift        # NEW — BGAppRefreshTask
WeeklyPlanner/Stores/InboxStore+Gmail.swift                        # MODIFY — accept(suggestion) creates Event
WeeklyPlannerTests/Gmail/GmailClientTests.swift                    # NEW (mocked URLSession)
WeeklyPlannerTests/Gmail/MessageClassifierTests.swift              # NEW
WeeklyPlannerTests/Gmail/EventExtractorTests.swift                 # NEW (mocked model)
WeeklyPlannerTests/Gmail/InboxSyncEngineTests.swift                # NEW (end-to-end with fakes)
```

## Visual & Interaction Checklist

This phase has no new UI; it powers existing UI surfaces:
- [ ] Day Page inbox block (Phase 06) starts displaying real suggestions.
- [ ] Tapping the green "+" on an inbox row commits the suggestion → creates an `Event` → mirrored to EventKit → vanishes from the inbox block with 0.25s collapse animation.
- [ ] Tapping the dismiss "×" marks the suggestion `dismissed`; never re-suggested by the engine.
- [ ] Pull-to-refresh on the Day Page (and Week Page) triggers `InboxSyncEngine.sync(now:)` — show a tiny chrome-aware progress indicator in the top bar.

## Logic & Data Checklist

### `GmailClient`
- [ ] Uses `URLSession` with token from `GoogleAuthService.accessToken()`.
- [ ] Endpoints:
  - `GET /gmail/v1/users/me/messages` with `q=` (filter), `maxResults=50`.
  - `GET /gmail/v1/users/me/messages/{id}` with `format=full` (or `metadata` to start).
  - `GET /gmail/v1/users/me/history?startHistoryId=` for incremental.
  - `GET /gmail/v1/users/me/profile` for the `historyId`.
- [ ] Rate-limit handling: respect `429` `Retry-After`; exponential backoff up to 5 retries.

### `GmailQueryBuilder`
- [ ] Default query string filters:
  - `(from:reservations OR from:tickets OR from:noreply OR from:reception OR subject:(invite|confirmation|reservation|ticket|appointment)) newer_than:14d`.
  - Skip `category:promotions` and `category:social`.
- [ ] User can customize in Settings (defer to v1.1; default-only for v1.0).

### `MessageClassifier`
- [ ] Two-stage pipeline:
  1. **Cheap rules**: subject keywords ("appointment", "confirmed", "ticket", "reservation", "invite", "RSVP"), known event-y senders (Resy, OpenTable, Ticketmaster, Eventbrite, Airbnb, calendar invite domains). Skip if neither matches.
  2. **AI gate**: pass through `EventExtractor` only if rule layer passes — Foundation Models is expensive.
- [ ] Output: `Bool` (looks like an event), and a confidence score.

### `EventExtractor` (Foundation Models)
- [ ] Inputs: message subject, snippet, from name + email, body (truncated to 3000 chars).
- [ ] Output schema: `{ isEvent: Bool, title: String?, startISO: String?, endISO: String?, location: String?, categoryHint: String?, confidence: 0–1 }`.
- [ ] Use structured output mode of `LanguageModelSession` with a Decodable target.
- [ ] System prompt: `"Extract a single calendar event from this email. If no event is present, return isEvent=false."`.
- [ ] Refuses to invent details; missing fields stay nil.

### `GmailDeltaSync`
- [ ] Stores last `historyId` per account in SwiftData (in `UserSettings.gmailLastHistoryId`).
- [ ] On each sync: call `history?startHistoryId=<last>`; for each new message in `messagesAdded`, fetch + classify + extract.
- [ ] If `history` returns 404 (history expired), full re-sync `newer_than:14d`.

### `InboxSyncEngine`
- [ ] Public: `sync(now:) async throws -> SyncResult { added, updated, dismissed }`.
- [ ] Pipeline:
  1. Token check via `GoogleAuthService`.
  2. Fetch new messages (delta).
  3. For each, classify; if pass, run `EventExtractor`.
  4. Upsert `InboxSuggestion` rows (deduplicated by `gmailMessageID`).
  5. If extractor proposes a date in the past or unparseable, skip.
  6. Save `historyId`.
- [ ] Concurrency: at most 1 concurrent sync; queued otherwise.
- [ ] Emits progress via `AsyncStream<SyncProgress>` for UI.

### `BackgroundRefreshScheduler`
- [ ] Registers `BGAppRefreshTask` identifier `"com.<org>.WeeklyPlanner.gmailRefresh"`.
- [ ] Default cadence: every 1 hour while charging or near-Wi-Fi; minimum 15 minutes between attempts.
- [ ] Submitted via `BGTaskScheduler` after each foreground sync.

### Accepting / dismissing a suggestion
- [ ] `accept(id:)`:
  - Reads `InboxSuggestion`.
  - Builds an `Event` with `source = .gmail`, `gmailMessageID/from/subject` populated, plus `start/end`, `title`, `location`, `category`.
  - Inserts via `EventStore.upsert` (which mirrors to EventKit via Phase 04 decorator).
  - Marks suggestion `accepted` (kept in DB for audit but excluded from `pending(...)`).
- [ ] `dismiss(id:)`:
  - Marks suggestion `dismissed`.
  - On next sync, this `gmailMessageID` is skipped.

## Tests (TDD)

`GmailClientTests`
- [ ] `testListMessagesWithQueryEncodesURL()`.
- [ ] `testFetchMessageRetriesOn429()`.
- [ ] `testHistoryReturns404TriggersFullResync()`.

`MessageClassifierTests`
- [ ] `testTicketmasterEmailPassesRules()`.
- [ ] `testPromotionalEmailRejected()`.
- [ ] `testGenericTransactionalEmailFallsToAIGate()`.

`EventExtractorTests` (mocked LanguageModelSession)
- [ ] `testResyConfirmationExtractsRestaurantAndTime()`.
- [ ] `testAmbiguousEmailReturnsIsEventFalse()`.
- [ ] `testMissingTimeReturnsNilStart()`.

`InboxSyncEngineTests`
- [ ] `testInitialSyncFetchesAndInsertsSuggestions()`.
- [ ] `testDeltaSyncOnlyProcessesNewMessages()`.
- [ ] `testAcceptCreatesEventInStore()`.
- [ ] `testDismissPreventsResuggestion()`.

## Acceptance Criteria
- A real Gmail account with sample Resy/Ticketmaster emails produces inbox suggestions within ~10s of toggling Gmail on.
- Day Page shows those suggestions under the events list.
- Accepting moves them into the calendar (visible in Apple Calendar within 2s).
- Background refresh keeps the inbox up-to-date without the user opening the app.
- Privacy: Gmail message bodies are processed entirely on-device; no network egress beyond Gmail API calls.

## Out of Scope
- Two-way sync (we don't reply to or modify emails).
- Smart batch-accept ("Accept all 3").
- Conflict detection between proposed events and existing calendar entries (defer v1.1).
- Localization of subject-keyword rules (Phase 21 may extend).

## Risks & Notes
- **Token refresh during background refresh**: BGTask budget is tiny; refreshing token alone could blow it. Cache aggressively.
- **Foundation Models in background**: framework may not be available outside foreground. Test on device — if not available, skip extraction step and rely on rules only.
- **PII leak risk**: never include raw email body in logs. Use `os_log` with `.private` privacy specifier.
- **Rate limits**: Gmail allows ~250 quota units/sec per user; full message read is 5 units. Plenty of headroom for v1.0 traffic.
- **Mailbox size**: large inboxes (>100k messages) — paginate. Default `maxResults=50` per sync.
