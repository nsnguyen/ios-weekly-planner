# Phase 37a — Google Calendar Import (two-way foundation) — Design

**Date:** 2026-06-14
**Status:** Draft (first of two increments toward the Phase 37 "real two-way Google Calendar sync"; 37b = write-back + conflict resolution)
**Area:** Google integration / event sync
**Refines:** `docs/phases/phase-37-google-calendar-sync.md`

## Problem

Settings → Connections has a "Google Calendar" row that has always been
"Coming soon, disabled" (Phase 17). Testers expected it to work
(`docs/suggestions.md` line 5). Phase 17 shipped Google **auth**; Phase 18 used
the token for Gmail only. This builds the calendar sync on that foundation.

The committed end state is **two-way** sync (roadmap headline). Because the read
path is the foundation the write path builds on, the work is split into two
increments that each ship and verify independently:

- **37a (this spec):** read/import + the shared foundation.
- **37b (next):** write-back (planner → Google) + conflict resolution.

## Desired behavior — 37a (confirmed with user)

- The Settings → Connections "Google Calendar" row is **enabled**: tap connects
  (reusing the Phase 17 OAuth sheet, now requesting the Calendar scope), shows
  the account + a syncing/connected status, and supports disconnect.
- After connecting, Google Calendar events appear in the planner's Day and Week
  views in the correct slots, sourced from the user's **primary** calendar.
- Re-sync is **incremental** and de-duplicated: editing an event in Google and
  re-syncing updates the existing planner row, never creates a duplicate.
- **Disconnect** removes every Google-sourced event and clears the sync cursor.

## Decisions (resolved; veto at review)

- **OAuth scope: request `calendar.events` (read + write) now.** Two-way is the
  committed end state, so requesting the write scope in 37a means one consent and
  no forced re-auth when 37b lands. 37a only *reads*; the scope is just pre-granted.
- **Google events are planner-only — the loop-prevention rule.** The app mirrors
  every SwiftData event into iOS Calendar via `EventKitMirroringEventStore`, and
  `EventKitSync` reads iOS-Calendar changes back. To stop a
  SwiftData ↔ iOS-Calendar ↔ Google loop, **the mirror decorator skips both
  upsert and delete for `source == .googleCalendar`**. Google events live only in
  SwiftData (for display) and Google (their origin). iOS's native Google account
  is how a user gets them into iOS Calendar if they want that.
- **Primary calendar only.** A multi-calendar picker is a later add.
- **Disconnect purges.** Sign out of the Calendar grant, delete all
  `source == .googleCalendar` rows, clear `gcalSyncToken` (mirrors Gmail
  disconnect's pending-suggestion cleanup).
- **Dedicated `GoogleCalendarClient`** (mirror `GmailClient`), not a generic
  shared Google API client — the shared concerns (auth/refresh/backoff) are
  already factored behind `GoogleAuthService` + the `URLSessionProtocol` seam;
  a shared abstraction now is premature.

## Approach — mirror the proven Gmail pipeline

### Components

| File | New/Modify | Role |
|------|-----------|------|
| `Auth/GoogleAuth/GoogleAuthConfig.swift` | Modify | add `https://www.googleapis.com/auth/calendar.events` to the requested scopes |
| `Stores/GoogleCalendar/GoogleCalendarClient.swift` | New | Calendar REST v3 reads over `URLSessionProtocol`; bearer token via `GoogleAuthService`, refresh-on-401, `Retry-After`/backoff on 429 — same shape as `GmailClient` |
| `Stores/GoogleCalendar/GCalEvent.swift` | New | Decodable DTOs: `GCalEvent` (id, summary, start/end `{date | dateTime}`, location, description, status, etag, updated), `GCalEventsListResponse` (items, `nextPageToken`, `nextSyncToken`) |
| `Stores/GoogleCalendar/GCalMapper.swift` | New | pure `GCalEvent → Event` mapping (`source = .googleCalendar`, `googleEventID = id`, all-day vs timed start/end, location, notes, a stable default category). Skips `status == "cancelled"` (those drive deletes) |
| `Stores/GoogleCalendar/GCalSyncEngine.swift` | New | `@MainActor` orchestrator: lists with **`singleEvents=true`** (Google expands recurring events into individual instances server-side — no client RRULE handling in 37a); incremental via `syncToken`, paginates `nextPageToken`, persists `nextSyncToken`; `410 Gone` → clear token + full resync over the window; single-flight; per-item `try/catch` so one bad event doesn't kill the batch; upserts mapped events + deletes `cancelled` ones via `EventStoring` |
| `Models/Event.swift` | Modify | add `var googleEventID: String? = nil` (property-level default — SwiftData lightweight-migration rule, per the `autoPlaced` lesson) |
| `Models/UserSettings.swift` | Modify | add `gcalSyncToken: String?`; reuse `googleCalendarConnected` |
| `Stores/EventKit/EventStore+EventKit.swift` | Modify | `upsert`/`delete` skip the EventKit mirror when `event.source == .googleCalendar` (loop prevention) |
| `Features/Settings/ConnectionsViewModel.swift` | Modify | `connectGoogleCalendar(presenter:)` / `disconnectGoogleCalendar()` mirroring the Gmail choreography; status + error/denied alert |
| `Features/Settings/ConnectionRow.swift` / `ConnectionsSection.swift` | Modify | enable the Google Calendar row (interactive); connected status line; re-auth banner on revoked access |
| `Stores/Gmail/BackgroundRefreshScheduler.swift` | Modify | register/append a `googleCalendarRefresh` task (or generalize) that runs `GCalSyncEngine` |
| `Stores/Environment+Stores.swift` | Modify | env keys for `GoogleCalendarClient?` + `GCalSyncEngine?` (optional so previews skip) |
| `App/WeeklyPlannerApp.swift` | Modify | construct the client + sync engine, inject them, kick a sync on `.googleCalendarDidConnect` and on launch when connected |

### Data flow

connect → OAuth (`calendar.events`) → persist `googleCalendarConnected` + email,
post `.googleCalendarDidConnect` → `GCalSyncEngine` full sync of the primary
calendar over a **2-months-back / 4-months-forward** window (matching
`EventKitSync`) → for each item: `cancelled` → delete by `googleEventID`,
otherwise `GCalMapper` → `Event(source: .googleCalendar, googleEventID:)` →
`EventStoring.upsert` (mirror-skipped) → persist `nextSyncToken` → events render
in Day/Week. Subsequent syncs send the stored `syncToken` (incremental); a
`410 Gone` clears it and re-runs the full window.

### Loop & dedup invariants

- **No EventKit round-trip:** Google events are never written to iOS Calendar
  (mirror skip), so `EventKitSync` never re-imports them. Single source of truth
  for `.googleCalendar` events = Google (read) → SwiftData (display).
- **Dedup/update by `googleEventID`:** upsert matches the existing row by
  `googleEventID`, so re-sync updates in place. Disconnect deletes exactly the
  `.googleCalendar` rows.

## Error handling

- **401** → `GoogleCalendarClient` refreshes the token once and retries (as
  `GmailClient`); persistent failure surfaces a re-auth banner.
- **429** → honor `Retry-After` / exponential backoff, bounded retries.
- **410 Gone** (expired `syncToken`) → drop the cursor, full resync.
- **Per-item map failure** → logged and skipped; the batch continues.
- **Revoked access / denied scope** → connection alert with a re-auth path
  (mirror the Gmail/denied pattern); leaves existing synced rows until disconnect.

## Testing (TDD)

Unit, fully stubbed with `URLProtocolStub` (no network — mirrors `GmailClientTests`):

- **`GoogleCalendarClientTests`:** happy-path list; `401 → refresh → retry`;
  `429` backoff; `syncToken` continuation + pagination; `410 → full-resync` signal.
- **`GCalMapperTests`:** all-day (`date`) vs timed (`dateTime`) start/end;
  with/without location/description; `cancelled` status routes to delete;
  round-trips `googleEventID`.
- **`GCalSyncEngineTests`:** delta (has token) vs full (nil/410) decision;
  single-flight guard; one bad item doesn't kill the batch; dedup by
  `googleEventID` (re-sync updates, no duplicate); disconnect purges only
  `.googleCalendar` rows.
- **`EventStore+EventKit` test:** a `.googleCalendar` upsert/delete does **not**
  touch the EventKit gateway (loop-prevention invariant).

**Live verification (manual, user):** add the `calendar.events` scope to the
Google Cloud OAuth consent screen, connect a real account on-device, confirm
events import into Day/Week and disconnect clears them. (The "unverified app"
interstitial from Phase 17 may appear.)

## Out of scope (37a)

- **Write-back** (planner → Google) and **conflict resolution** — Phase **37b**.
- Multi-calendar selection UI (primary only).
- Client-side recurrence handling: recurring events import as Google-expanded
  single instances (`singleEvents=true`); we do **not** store the RRULE/master
  or author recurring events into Google — that's 37b+.
- Non-Google CalDAV providers.
