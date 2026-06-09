# Top-Bar Gap — Design

**Date:** 2026-06-08
**Status:** Approved
**Area:** Calendar tab header (`BookTopBar`)

## Problem

On the calendar (Day/Week) screen there is a large empty dark band between the
status bar and the "THE PLANNER · WEEK N" header, wasting vertical space that
could go to the paper page.

## Root cause

`BookTopBar` wraps its two header rows in
`.padding(EdgeInsets(top: 54, leading: 26, bottom: 8, trailing: 16))`
(`BookTopBar.swift:65`). The header already lays out **inside** the safe area —
only `BookCover` calls `.ignoresSafeArea()` (`BookCover.swift:15`); nothing in
the calendar render path (`AppShell` → `BookContainer` → `BookTopBar`) ignores
the top safe area. So the `top: 54` is measured from the safe-area top (already
below the Dynamic Island / notch / status bar) and is almost entirely
**extra empty gap**, not status-bar clearance. The code's "Dynamic Island
clearance" framing is therefore misleading.

## Desired behavior

The header sits just below the status bar with a small comfortable margin; the
reclaimed space goes to the paper page. (Decision: "pull header up" — header
internals unchanged.)

## Change

In `BookTopBar.swift:65`, reduce the top inset from `54` to **≈12**, keeping
`leading: 26, bottom: 8, trailing: 16`:

```swift
.padding(EdgeInsets(top: 12, leading: 26, bottom: 8, trailing: 16))
```

- The exact value (≈12) is tuned visually during verification — a few points
  either way is fine; the goal is a small breathing margin under the safe-area
  top, not zero.
- Update the misleading "Dynamic Island clearance" comment on/near this line so
  it reflects reality: the **safe area** clears the island; this inset is just
  breathing room below it.

## Why it is safe across devices

Because the header respects the safe area, the inset is additive to whatever the
safe area already reserves. Dynamic-Island phones, notched phones, and flat-top
phones each get their correct safe inset plus the same uniform ~12pt — no
device-specific branching needed. The `VStack(spacing: 0)` in `BookContainer`
(`BookContainer.swift:80`) stacks header → page → bottom controls with no gaps,
so the ~42pt reclaimed flows directly into the page area.

## Verification

This is a visual constant with no logic change:

- Build and run on an iPhone 17 simulator (Dynamic Island). Screenshot the
  calendar tab; confirm the header clears the island with a comfortable margin
  and the paper page visibly gained vertical room. Tune the constant by a few
  points if it looks tight or loose.
- The full `WeeklyPlannerTests` suite stays green (no behavioral change).

## Scope / out of scope

- **In scope:** the calendar tab header only (`BookTopBar`, shared by Day and
  Week views via `BookContainer`).
- **Out of scope:** header internal row spacing and bottom padding (kept as-is
  per the "pull header up" decision); the Review / Notes / Settings tabs (separate
  views — a follow-up if they show the same gap); the bottom controls / tab bar.
