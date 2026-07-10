# Phase 37b — Google Calendar Write-Back — Design

**Date:** 2026-07-09  
**Status:** Approved (pending user review of this written spec)  
**Area:** Google integration / event sync  
**Refines:** `docs/phases/phase-37-google-calendar-sync.md`  
**Builds on:** `docs/superpowers/specs/2026-06-14-phase-37a-google-calendar-import-design.md`

## Problem

Phase 37a shipped **pull-only** Google Calendar sync: events created or edited
in Google appear in the planner, but events created in this app never appear in
Google Calendar. Users experience this as “sync that only goes one way.”

Phase 37b adds **write-back** (planner → Google) so connected accounts get real
two-way sync for single events. Full recurrence parity is deferred to **37c**.

## Desired behavior (confirmed)

- When Google Calendar is connected, **create / edit / delete** of events in the
  app push to the user’s **primary** Google Calendar.
- **Last-write-wins** on conflict (compare timestamps; newer side wins).
- Push happens **immediately** on create/edit/delete (when online).
- After a successful push, the event is **reclassified as Google-sourced**
  (`source = .googleCalendar`) so EventKit mirroring is skipped (loop prevention
  from 37a).
- Delete in the app **cancels** the Google event (`status: cancelled`), not a
  hard delete.
- **37b ships single (non-recurring) events only.** Recurring events stay
  local / EventKit-mirrored; no Google push until 37c (full recurrence parity
  including exceptions / “this event only”).

## Decisions (resolved)

| Decision | Choice | Why |
|----------|--------|-----|
| Scope of push | All create/edit/delete while connected | User wants full two-way for local events |
| Conflict policy | Last-write-wins | Simple, no conflict UI in v1 |
| Push timing | Immediate | Best UX; no durable outbox in 37b |
| Recurrence | Single events only in 37b; 37c = full parity | Ship write-back without blocking on RRULE edge cases |
| Post-push identity | Flip to `.googleCalendar` | Reuses 37a EventKit skip; avoids SwiftData ↔ iOS ↔ Google loops |
| Delete semantics | Cancel on Google | Safer for invitees; matches import’s cancelled → delete path |
| Architecture | Decorator on `EventStoring` | One choke point; mirrors `EventKitMirroringEventStore` |
| Calendar target | Primary only | Same as 37a; multi-calendar picker later |
| Offline / failed push | Local save succeeds; stay non-Google until successful push; non-blocking error | Avoids inventing an outbox in 37b |

## Approach — write-back decorator outside EventKit

### Stack (outer → inner)

```
GoogleCalendarWriteBackEventStore
  → EventKitMirroringEventStore
    → SwiftDataEventStore
```

Write-back is **outside** EventKit mirroring so that after a successful push we
set `source = .googleCalendar` **before** the EventKit decorator sees the write,
and the existing 37a guard skips the iOS Calendar mirror.

### Components

| File | New/Modify | Role |
|------|------------|------|
| `Stores/GoogleCalendar/GoogleCalendarClient.swift` | Modify | Add `createEvent`, `updateEvent`, `getEvent`, `cancelEvent` on primary calendar; reuse 401-refresh + 429 backoff |
| `Stores/GoogleCalendar/GoogleCalendarClientProtocol` | Modify | Extend protocol with write methods |
| `Stores/GoogleCalendar/GCalMapper.swift` | Modify | Add `Event →` insert/update JSON body; map remote `updated`/etag for LWW |
| `Stores/GoogleCalendar/GoogleCalendarWriteBackEventStore.swift` | New | `EventStoring` decorator: push on upsert/delete when connected + non-recurring; echo-guard for import |
| `Stores/GoogleCalendar/GCalSyncEngine.swift` | Modify | Mark mutations as “from sync” so write-back does not echo |
| `Models/Event.swift` | Modify | Add `googleEtag: String? = nil` (property default for lightweight migration) |
| `App/WeeklyPlannerApp.swift` | Modify | Wrap: write-back → EventKit → SwiftData; inject client + settings (or a `() -> Bool` connected probe reading `UserSettings.googleCalendarConnected`) |
| `Stores/Environment+Stores.swift` | Review | Ensure previews/tests can omit write-back |

### Data flow

**Create (connected, non-recurring)**  
1. `upsert(event)` enters write-back decorator.  
2. `POST /calendars/primary/events` with mapped body.  
3. On success: set `googleEventID`, `googleEtag`, `source = .googleCalendar`.  
4. Persist via inner store → EventKit mirror skipped.

**Edit (has `googleEventID`)**  
1. `GET` remote event (or use fresher sync data if already available).  
2. Compare remote `updated` (RFC3339) to local `updatedAt`.  
3. Local newer or equal → `PUT`/`PATCH` with If-Match etag; store new etag.  
4. Remote newer → apply remote → local (same mapping as import); skip push.  
5. **412 Precondition Failed** → re-fetch, re-run compare once; if still contested, remote wins that pass.

**Delete**  
1. If `googleEventID` present → cancel on Google (`status: cancelled`).  
2. Remote already cancelled/gone (404/410) → treat as success.  
3. Delete local row (EventKit path already skipped for Google source).

**Import path**  
`GCalSyncEngine` upserts/deletes with an echo guard (flag / task-local) so the
write-back decorator does **not** POST/PUT back to Google.

**Recurring (37b)**  
`recurrence != nil` → pass through to inner store only; no Google API call.

**Push failure**  
Local write still succeeds via inner store with original `source` (typically
`.manual`). Surface a non-blocking error. A later successful edit/retry can push.

### Loop & identity invariants

- Google-sourced events never mirror to EventKit (37a rule, unchanged).
- Successful write-back **becomes** Google-sourced so the same rule applies.
- Dedup remains by `googleEventID` on import.
- Write-back must not run for mutations originating from `GCalSyncEngine`.

## Error handling

- **401** → refresh once (existing client); persistent → re-auth banner.
- **403 / insufficient scope** → prompt reconnect for Calendar.
- **429** → Retry-After / exponential backoff (existing).
- **412** → one re-fetch + LWW re-decide; remote wins if still contested.
- **Network / 5xx on push** → keep local; non-blocking failure; leave non-Google until success.
- **Import failures** → unchanged from 37a.

## Testing (TDD)

Stubbed `GoogleCalendarClientProtocol` / `URLProtocolStub` — no live network:

- **Create** → POST → `googleEventID` set, `source == .googleCalendar`, EventKit gateway not called.
- **Update** → local wins / remote wins / 412 retry path.
- **Delete** → cancel then local delete; already-cancelled remote = success.
- **Recurring upsert/delete** → no Google write methods invoked.
- **Sync-engine upsert** → no echo write-back.
- **Client** → create/update/get/cancel; 401 refresh; 429 backoff.

**Live verification (manual):** connect Google Calendar, create/edit/delete a
single event in-app, confirm it appears/updates/cancels in Google Calendar (web
or Calendar.app via Google account). Confirm a recurring event does **not** push.

## Out of scope

- Full recurrence / exceptions / “this event only” → **Phase 37c**.
- Multi-calendar selection UI (primary only).
- Durable outbox / offline mutation queue.
- Hard-delete on Google.
- Non-Google CalDAV providers.
- Changing 37a import window, disconnect purge, or OAuth scope (already
  `calendar.events` from 37a).

## Follow-on — Phase 37c (not designed here)

End goal stated by product: full recurrence parity with Google (RRULEs,
exceptions, “this event only”). 37b deliberately does not push recurring events
so 37c can own that surface without shipping a half-broken series sync.
