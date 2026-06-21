# Phase 37 — Google Calendar Sync

> **Status (2026-06-20):** **37a — Read/import: SHIPPED to `main` and verified
> on-device.** Connect imports primary-calendar events into Day/Week; incremental
> re-sync, dedup, disconnect-purge, EventKit-loop prevention all working. Commits
> `02afcdf..485de80` (feature) + `234f058`/`1e28006`/`4be8243` (sign-in hardening
> & API error logging). **37b — Write-back + conflict resolution: not started.**
> Design: `docs/superpowers/specs/2026-06-14-phase-37a-google-calendar-import-design.md`.

> **Milestone M (v1.1 Features).** Post-submission. Covers `docs/suggestions.md`
> line 5: *"Google Calendar sync not working."* Reclassified bug → feature: the
> connections row has always been "Coming soon, disabled" (Phase 17) — nothing
> regressed; this builds it.

## Goal
Turn the dormant Google Calendar connection into a working sync: read Google
Calendar events into the planner (and, where scoped, write planner events
back), behind the existing Settings → Connections row.

## Why this is needed
Testers expected the Google Calendar row to work and reported it as broken.
Phase 17 shipped the Google **auth** foundation and a disabled "Coming soon"
row; Phase 18 used the token for Gmail only. Calendar sync is the natural next
use of that token and a frequently-requested integration.

## Prerequisites
- Phase 17 (Google OAuth foundation: `LiveGoogleAuthService`,
  `TokenKeychainStore`, `GoogleAuthConfig`), Phase 04 (EventKit / EventStore),
  Phase 18 (the `GmailClient` URLSession-seam pattern to mirror). *(Shipped.)*
- Phase 27's copy stop-gap (clarified disabled row) should already be out.

## Files Created / Modified

```
WeeklyPlanner/Auth/GoogleAuth/GoogleAuthConfig.swift        # MODIFY — add Calendar scope (calendar.readonly, or calendar.events for write)
WeeklyPlanner/Stores/GoogleCalendar/GoogleCalendarClient.swift   # NEW — REST v3 over URLSessionProtocol (mirror GmailClient: bearer + refresh-on-401 + backoff)
WeeklyPlanner/Stores/GoogleCalendar/GCalEvent.swift         # NEW — wire model + mapping to/from app Event
WeeklyPlanner/Stores/GoogleCalendar/GCalSyncEngine.swift    # NEW — incremental sync (syncToken), single-flight, per-item try/catch
WeeklyPlanner/Stores/GoogleCalendar/GCalMapper.swift        # NEW — GCalEvent <-> Event (+ category/source mapping, source=.googleCalendar)
WeeklyPlanner/Models/EventSource.swift                      # MODIFY — add .googleCalendar source
WeeklyPlanner/Models/UserSettings.swift                     # MODIFY — gcalSyncToken cursor + connection state
WeeklyPlanner/Features/Settings/ConnectionRow.swift         # MODIFY — Google Calendar row becomes interactive (connect/disconnect/status)
WeeklyPlanner/Features/Settings/ConnectionsViewModel.swift  # MODIFY — connect/disconnect choreography for Calendar (mirror Gmail)
WeeklyPlanner/Features/Settings/ConnectionsSection.swift    # REVIEW — status line + error/denied banners
WeeklyPlanner/Stores/Gmail/BackgroundRefreshScheduler.swift # REVIEW — register/append a calendar refresh task
WeeklyPlannerTests/GoogleCalendar/GoogleCalendarClientTests.swift # NEW — URLProtocolStub: fetch, 401-refresh, 429-backoff, syncToken
WeeklyPlannerTests/GoogleCalendar/GCalMapperTests.swift     # NEW — round-trip mapping fidelity
WeeklyPlannerTests/GoogleCalendar/GCalSyncEngineTests.swift # NEW — delta vs full, single-flight, per-item failure isolation
```

## Visual & Interaction Checklist
- [ ] The Settings → Connections "Google Calendar" row is **enabled**: tap to
      connect (reuses the Phase 17 OAuth sheet, now requesting the Calendar
      scope), shows account + "syncing", and supports disconnect.
- [ ] After connecting, Google Calendar events appear in the planner's Day and
      Week views in the correct slots.
- [ ] Disconnect clears synced events sourced from Google Calendar and the
      stored sync cursor (mirroring the Gmail disconnect cleanup).
- [ ] Connection errors / revoked access surface a clear banner with a re-auth
      path (mirror the Gmail/denied-notification banner pattern).

## Logic & Data Checklist
- [ ] `GoogleCalendarClient` reuses the `URLSessionProtocol` seam and the
      bearer-token + auto-refresh-on-401 + `Retry-After` backoff behaviors
      established by `GmailClient`; tests use `URLProtocolStub`.
- [ ] Incremental sync via Google's `syncToken`; a `410 Gone` (expired token)
      falls back to a full re-sync (mirror the Gmail history-expiry pattern).
- [ ] Mapped events carry `source = .googleCalendar` and a round-trip Google
      event id so re-sync updates rather than duplicates, and so disconnect can
      purge exactly the Google-sourced rows.
- [ ] **Decide read vs read-write in `writing-plans`:** default v1 to
      **read-only import** (`calendar.readonly`) to de-risk; write-back
      (creating planner events in Google) is a follow-on. State the choice in
      the plan and request the matching OAuth scope.
- [ ] Interaction with the existing EventKit mirror is defined: Google events
      should not double-mirror into iOS Calendar in a way that creates loops —
      pick one storage path and document it.

## Tests (TDD)
- [ ] `GoogleCalendarClientTests` — happy path, 401→refresh→retry, 429 backoff,
      syncToken continuation, 410→full-resync.
- [ ] `GCalMapperTests` — all-day, timed, with/without location, recurrence
      (read) map correctly.
- [ ] `GCalSyncEngineTests` — delta vs full decision, single-flight guard,
      one bad item doesn't kill the batch.

## Acceptance Criteria
- Connect → Google events import and display; disconnect → clean removal.
- Sync is incremental, resilient (401/429/410), and de-duplicated.
- Full suite green; verified on-device with a real Google account.

## Out of Scope
- Two-way write-back if scoped to read-only for v1 (follow-on).
- Multiple Google calendars selection UI (sync primary first; calendar picker
  later if asked).
- Non-Google CalDAV providers.

## Risks & Notes
- **OAuth verification:** adding the Calendar scope may require Google app
  re-consent and, for production, OAuth verification review. Plan for the
  "unverified app" interstitial in testing (as seen in Phase 17).
- **Loop risk** between Google sync, the SwiftData store, and the EventKit
  mirror — define the single source of truth per event source up front.
- Mirror the Gmail pipeline's resilience patterns rather than inventing new
  ones; they're already battle-tested on-device (Phase 18).
