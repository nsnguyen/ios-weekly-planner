# Phase 11 — Paper Event Detail Sheet (Torn-Page Bottom Sheet)

## Goal
Build the bottom sheet that opens when an event is tapped — a torn-paper card with category chip, ink title, time range, location row, travel time, alert toggle, "when I arrive" toggle, invitees row, AI suggestion sticky, and a dashed-red "Tear out this page" delete button. Wire reminders (time + location) into EventKit.

## Why this is needed
The event sheet is where users **edit** events. It binds the visible aesthetic to real Calendar/Reminders behavior.

## Prerequisites
- Phases 02 (theme), 03 (`Event`, `Reminder`, `LocationReminder`), 04 (EventKit save/delete), 05 (`TornEdgeShape`, `MaskingTape`, `PaperToggle`, `DashedBorder`).

## Files Created / Modified

```
WeeklyPlanner/Features/EventDetail/PaperEventSheet.swift          # NEW — root view
WeeklyPlanner/Features/EventDetail/EventHeader.swift              # NEW — category chip + title + time
WeeklyPlanner/Features/EventDetail/EventLocationRow.swift         # NEW — pin + location + "Tap to open in Maps"
WeeklyPlanner/Features/EventDetail/EventTravelRow.swift           # NEW — car + minutes
WeeklyPlanner/Features/EventDetail/EventAlertRow.swift            # NEW — bell + minutes-before + toggle
WeeklyPlanner/Features/EventDetail/EventLocationAlertRow.swift    # NEW — "When I arrive" + toggle
WeeklyPlanner/Features/EventDetail/EventInviteesRow.swift         # NEW — people + count
WeeklyPlanner/Features/EventDetail/EventAISticky.swift            # NEW — yellow suggestion sticky inside sheet
WeeklyPlanner/Features/EventDetail/EventDeleteButton.swift        # NEW — "Tear out this page"
WeeklyPlanner/Features/EventDetail/EventDetailViewModel.swift     # NEW — load + edit + save + delete
WeeklyPlanner/Features/EventDetail/MapsLinker.swift               # NEW — open in Apple Maps (universal link)
WeeklyPlannerTests/Features/EventDetailViewModelTests.swift       # NEW
WeeklyPlannerTests/Features/EventDetailSnapshotTests.swift        # NEW
```

## Visual & Interaction Checklist

### Backdrop + sheet container
- [ ] Backdrop covers entire screen `inset: 0`, `rgba(0,0,0,0.45)` opacity, z-index 180.
- [ ] Animation: `pesFade` 0.22s ease-out.
- [ ] Sheet container: `leading: 16, trailing: 16, bottom: 0, maxHeight: 85%`. z-index 190.
- [ ] Padding-bottom 32 (safe area).
- [ ] Animation: `pesSlide` 0.32s `cubic-bezier(0.2, 0.8, 0.2, 1)` from translateY 100% → 0.
- [ ] Tap backdrop → dismiss.

### Torn-paper card
- [ ] Background: radial gradient (ellipse 18%/30%, `creamHi → cream@55% → creamLo`) over solid `cream`.
- [ ] Corners: `top: 4 4, bottom: 14 14`.
- [ ] Shadow: `0 -8 30 rgba(0,0,0,0.5), 0 -1 0 rgba(255,255,255,0.06)`.
- [ ] Overflow hidden.
- [ ] Min height 360pt.
- [ ] **Torn top edge**: `TornEdgeShape` (Phase 05) layered at top-0 height 10pt. Uses CSS mask in the mock; in SwiftUI, render the cream-colored zigzag shape clipped from a 10pt-tall band positioned `top: -8`.

### Top decorations
- [ ] Red margin: `leading: 32, top: 14, bottom: 0`, width 1pt, color `theme.redLine`.
- [ ] Three hole punches across the top at `leading: 14, top: 18`, 10×10 each, spaced 60pt apart horizontally.

### `EventHeader`
- [ ] Padding `38 18 14 44`. Flex row align-flex-start, gap 10.
- [ ] **Left column** (flex 1):
  - Category chip:
    - Inline-flex pill, padding `2 8`, background `rgba(0,0,0,0.04)`, border `0.5pt theme.ink3`, radius 2pt.
    - 5×5 dot + category name uppercase (system 9pt weight 700 letter-spacing 1.2, color `ink2`).
    - marginBottom 6pt.
  - Title: handwriting 28pt weight 700, line-height 1.05, color = category ink.
  - Time: handwriting 17pt, color `ink2`, marginTop 3. Format: `"{weekday} · {start} – {end}"` e.g., `"Saturday · 8 PM – 11 PM"`.
- [ ] **Close button** (top-right): 14×14 svg `×`, stroke `theme.ink2`, padding 6pt around for hit area. Tap dismisses.

### Body rows (padding `0 18 18 44`)

Each row uses a shared `PaperRow` style: flex row align-center gap 12, padding `11pt vertical`, border-bottom 0.5pt `theme.rule` (except last visible row).

#### `EventLocationRow` (visible if `event.location != nil`)
- [ ] Leading icon: pin 16pt in `ink2`.
- [ ] Middle (flex 1):
  - Line 1: handwriting 18pt, `ink`. Format `"↳ {location}"`.
  - Line 2: system 11pt color `ink3`, `"Tap to open in Maps"`.
- [ ] Trailing chevron `›` 12pt in `ink3`.
- [ ] Tap → `MapsLinker.open(location:)` via `UIApplication.shared.open(URL(string: "https://maps.apple.com/?q=\(URL-encoded)")!)`.

#### `EventTravelRow` (visible if `event.travelMinutes != nil`)
- [ ] Car icon 16pt `ink2` + handwriting 17pt "Travel time" + trailing system 13pt `ink2` `"{n} min"`.

#### `EventAlertRow`
- [ ] Bell 16pt + label `"Alert me"` (handwriting 17pt) + sublabel (system 11pt `ink3`): if on `"15 minutes before"`, if off `"Off"`.
- [ ] `PaperToggle` (compact, 38×22).
- [ ] When toggled on: adds `Reminder.timeBefore(minutes: settings.defaultReminderMinutes ?? 15)` to event; if off, removes time-based alarms.
- [ ] Tapping the label area (not the toggle) opens a small inline picker `[None, 5, 15, 30, 60]` (Phase-16-style PrefRow) — defer to v1.1; v1.0 ships toggle only.

#### `EventLocationAlertRow`
- [ ] Pin 16pt + label `"When I arrive"` + sublabel: if on `"at {location}"`, if off `"Off"`.
- [ ] `PaperToggle` (compact).
- [ ] When toggled on AND `event.location != nil`: geocode the location string to lat/lon (CoreLocation), create `LocationReminder` with 100m radius, attach to event via `Reminder.onArrive(...)`.
- [ ] Permission flow for Location-When-In-Use kicks in here (first time).

#### `EventInviteesRow` (visible if `event.attendeesCount > 1`)
- [ ] People icon + label `"Invitees"` + trailing `"{n} people"` + chevron.
- [ ] Tap → presents a basic list of attendee names if available from EventKit `EKEvent.attendees`. Stretch — show "Coming soon" placeholder if EventKit data is empty (most user-created events have no attendee data).

### `EventAISticky`
- [ ] Yellow sticky (`#FFE680`), padding `10 12`, rotated -0.6°, shadow `0 3 8 rgba(0,0,0,0.18)`, radius 1pt, marginTop 14.
- [ ] Eyebrow `SUGGESTED` (system 8pt weight 700, letter-spacing 1.2, color `rgba(0,0,0,0.45)`, marginBottom 3): includes a 9×9 sparkles icon.
- [ ] Body: handwriting 16pt weight 600, color `#3A2A1A`, line-height 1.2.
- [ ] Content from `aiSuggestionFor(eventID)`:
  - `e17` → `"Order an Uber at 7:35 PM. Trick Dog is a 22-min drive Saturday night."`
  - `e2`  → `"You haven't replied to Sara about Saturday. Want me to draft a quick message?"`
  - `e4`  → `"Tuesday morning has light traffic to 4th Street. Leaving by 9:35 should work."`
  - Default → `"Block 15 min of focus time before this so you're not rushing in."`
- [ ] In production, suggestions come from Foundation Models (Phase 13); seed map is for previews/tests.

### `EventDeleteButton`
- [ ] Full-width button. Margin-top 14, padding `10pt vertical`.
- [ ] Background transparent. Border: 0.5pt **dashed** `theme.redInk`. Radius 4pt. Letter-spacing 0.4.
- [ ] Text: handwriting 17pt weight 600, color `redInk`, `"Tear out this page"`.
- [ ] Tap → confirmation alert: `"Delete this event?"` / `"Delete"` (destructive) / `"Cancel"`.
- [ ] Confirm → delete from `EventStore` (also removes from EventKit via Phase 04 decorator). Sheet dismisses; the row disappears from Day/Week views.

### Bottom-right page corner
- [ ] 24×24 gradient page-curl (slightly smaller than DayPage curl). Same gradient recipe.

## Logic & Data Checklist

### `EventDetailViewModel`
- [ ] Input: `eventID: UUID`.
- [ ] Loads `Event` from `EventStore`.
- [ ] Local state: `alertOn: Bool`, `alertMinutes: Int`, `locationAlertOn: Bool`.
- [ ] On toggle, updates `event.reminders` and saves via `EventStore.upsert`.
- [ ] On delete, calls `EventStore.delete(id:)`.
- [ ] Emits `dismiss` event on save+delete completion (passed via callback).

### Apple Maps deep link
- [ ] Encode location string + optional lat/lon. Use `maps://?q=<query>` for native, fallback `https://maps.apple.com/?q=<query>`.

### Location geocoding
- [ ] Use `CLGeocoder.geocodeAddressString(_:)` async. Cache result on `Event.locationCoordinate` so we don't re-geocode every toggle.
- [ ] On geocoding failure, show inline toast `"Couldn't find location"` and revert the toggle.

### Sheet presentation
- [ ] Presented from Day page or Week page via `@State openEventID: UUID?`.
- [ ] On dismiss (tap backdrop / close button / slide down ≥ 80pt drag), animates out 0.32s and clears state.

### Drag-to-dismiss
- [ ] Down-drag with `translation.height > 80` AND `velocity.y > 200` → dismiss.
- [ ] During drag, the sheet translates with the finger and the backdrop fades proportionally.

## Tests (TDD)

`EventDetailViewModelTests`
- [ ] `testToggleAlertAddsReminderAt15Min()`.
- [ ] `testToggleAlertOffRemovesReminders()`.
- [ ] `testToggleLocationAlertGeocodesLocation()` — mock `CLGeocoder`.
- [ ] `testDeleteCallsEventStoreDelete()`.
- [ ] `testAISuggestionMappingFor_e17()`.

`EventDetailSnapshotTests`
- [ ] Snapshot of Sara's birthday (`e17`) — yellow AI sticky, family redInk title.
- [ ] Snapshot of Dentist (`e4`) — Gmail glyph in chip context (verify chip itself doesn't have one — chip is category, glyph appears via event details only when source is gmail; consider adding a small Gmail badge near the time line if `source == .gmail`).
- [ ] Snapshot in midnight theme.

## Acceptance Criteria
- Tapping any event on Day or Week pages opens the sheet.
- The torn paper top edge is visible and not clipped.
- Toggles persist after dismiss-reopen.
- Deleting removes from both the app and the iOS Calendar.
- "Tap to open in Maps" actually opens Apple Maps with the location query.
- Reduce-motion: skip the slide animation; use fade.

## Out of Scope
- Adding new events (deferred; Day/Week views read-only edit-existing in v1.0; "+" button hooks to AI overlay).
- Inline title editing (defer to v1.1; v1.0 shows title as read-only label; only toggles/delete are editable).
- Recurring events.

## Risks & Notes
- **`CLGeocoder` rate limits**: cache aggressively; never geocode in a loop.
- **`EKAlarm` with `structuredLocation`** requires user to grant Location-Always for reliable geofencing. We use Location-When-In-Use as a softer ask; document the limitation in Settings (Phase 17).
- **`TornEdgeShape` antialiasing** may show seams at scale 2.5×. Pre-render to a `MTLDrawable` if needed (defer).
- **Apple Maps link** with international characters needs `addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)`.
