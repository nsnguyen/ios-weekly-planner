# Phase 39 — Voice Memos

> **Milestone N (Future).** **Outline only — unscheduled.** Covers
> `docs/suggestions.md` line 53: *"Voice memo??"* (the user's own double
> question mark — this is exploratory). A full spec gets its own
> `superpowers:brainstorming` pass before execution.

## Goal
Let users capture a short voice memo and attach it to a day (and/or an event),
play it back, and manage it — a spoken counterpart to free-text notes.

## Why this is needed
Floated as a "maybe." Quick spoken capture suits a planner used on the go.
Marked exploratory: validate desirability (and the on-device transcription
angle) before investing.

## Prerequisites
- Phase 03 (models/persistence). Pairs naturally with Phase 33 (Notes) and
  Phase 34 (annotations) as another per-day content type.

## Rough Scope (to be detailed when scheduled)
- **Capture:** `AVAudioRecorder` behind a protocol seam (so it's testable);
  record/stop/cancel UI in the paper aesthetic.
- **Storage:** audio files in the app container, referenced by a `VoiceMemo`
  `@Model` (id, dayKey/eventId, fileURL, duration, created). Decide retention
  and size limits.
- **Playback:** inline play/pause + scrubber on the Day page (and event sheet
  if attached to an event).
- **Permissions:** `NSMicrophoneUsageDescription` in Info.plist + the privacy
  manifest (coordinate with Phase 25's privacy work) + first-use mic prompt.
- **Optional transcription:** on-device `Speech` (or Foundation Models) to
  produce a text preview — high value, but its own scope; likely a follow-on.
- **Backup/sync:** define whether memos are local-only (default) — they will
  **not** go to EventKit.

## Key Questions to Resolve First
- Is this worth building, or does free-text (Phase 34) already cover the need?
  Validate before scheduling.
- Attach to a **day**, an **event**, or both?
- Transcription in v1 or strictly audio?
- Storage/retention limits and privacy-manifest implications.

## Out of Scope (for the eventual phase, unless decided otherwise)
- Cloud storage / cross-device sync of audio.
- Editing audio (trim/merge).
- Transcription if deferred to a follow-on.

## Risks & Notes
- **New permission + new privacy-manifest entry** — must be declared for App
  Store review; loop in Phase 25's privacy work if this is scheduled near a
  release.
- Audio file lifecycle (orphans when a day/event is deleted) needs an explicit
  cleanup rule.
- Lowest-priority of the feedback set (the user's own "??"). Confirm demand via
  TestFlight before committing engineering time; brainstorm fully first.
