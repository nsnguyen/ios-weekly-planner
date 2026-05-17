# Handoff: iOS Weekly Planner — Paper Aesthetic

## Overview

A weekly planner iOS app with a **paper-planner aesthetic** — leather book binding, cream pages with hole punches, handwritten ink for events, AI sticky notes — sitting on top of a modern feature set: Apple Intelligence (RAG) search, multi-week navigation, Gmail-sourced events, time/location reminders, and an editable theme/font/size system.

Target device: iPhone (portrait). Designed to feel native to iOS but with a strong physical-paper visual metaphor that differentiates it from stock Calendar.

## About the Design Files

The files in this bundle are **design references created in HTML** — prototypes showing intended look and behavior. They are **not** production code to copy directly. The task is to **recreate these designs in the target codebase's existing environment** (SwiftUI for native iOS is the natural target) using its established patterns and libraries.

If you implement in native iOS:
- Use SwiftUI views, not WebView wrappers
- Use SF Symbols for iconography where appropriate
- Bridge to Apple Intelligence via the `Foundation Models` framework
- Use EventKit for calendar and reminders, MailKit (or Gmail API + OAuth) for inbox sourcing
- Custom fonts ship via the Info.plist `UIAppFonts` array

## Fidelity

**High-fidelity** — pixel-perfect mockups with final colors, typography, spacing, and interactions. Recreate the UI faithfully using the codebase's native primitives. The HTML prototype uses inline-styled React components; treat those as a spec, not as code to port.

## Screens / Views

### 1. Calendar — Day Page (default)

**Purpose:** User's primary view. One day per page, ink-styled events, tasks, and AI sticky notes layered like in a real physical planner.

**Layout:**
- Full-screen leather-book background (`PAPER.bookCover`, currently a 160° linear gradient from `#2C2418` → `#1A1410` in Cream theme).
- Top bar (`54px` top padding for status bar inset + dynamic island): two-row header.
  - Row 1: "The Planner · Week N" eyebrow (10px, letter-spacing 1.6, uppercase, opacity 0.65) over the date-range pill (Caveat 22px, white-cream). Flanked by `‹` / `›` chevron buttons (22×22) for week stepping, and a sparkles AI button + gear Settings button (34×34 / 30×30 rounded pills, 1px translucent border).
  - Row 2: Day/Week segmented toggle (62×24, rounded 7), and a "Today" pill that only appears when `weekOffset !== 0`.
- Page surface inset `0 18px 0 26px` against a darker `PAPER.bookSpine` book-spine color. Border-radius `4px 14px 14px 4px` to suggest the bound left edge.
- Page-edge stripes: 6px-wide vertical stripe pattern on the right side (`repeating-linear-gradient(180deg, #EFE5C9 0 2px, #E2D6B3 2px 4px)`) — suggests stacked paper edges.
- Side tabs: 22px-wide column of day tabs (M / T / W / T / F / S / S), each 56px tall, rotated text, soft pastel backgrounds (`['#E8D9B7', '#D9C9E3', '#C8DDE6', '#E4D3C2', '#D9E4C6', '#E7C7C7', '#CFD4DC']`). Selected tab is 28px wide, offset `-6px` left.
- The page itself: cream paper background (`PAPER.cream` = `#FAF6E9` in default theme), with:
  - Soft red margin line at `left: 32, width: 1, top: 0, bottom: 0` (`rgba(192,72,72,0.55)`)
  - Three hole-punch dots on the left edge (12×12, `#E8E0CB`, inset shadow)
  - Subtle radial-gradient grain for paper texture
  - Faint horizontal ruled lines (`repeating-linear-gradient(to bottom, transparent 0px, transparent 27px, rgba(139,121,80,0.18) 27px, rgba(139,121,80,0.18) 28px)`)
- Page header: weekday name in Caveat 30px on the left; giant rotated date number (Caveat 62px, rotated `-3°`, red ink `#9C2A2A` if today) on the right.
- "Today · 2:12 PM" dashed-border chip below header, when current day.
- Events list: time gutter (Cochin 13px, tabular nums, 48px wide, ink2 color) followed by event title in Caveat 21px in category ink color, with location below in italic Cochin 12px.
- Gmail-sourced events show a tiny Gmail icon (10×10 SVG) inline next to the title.
- To-do block at bottom: dashed-border yellow patch (`rgba(255,255,200,0.35)`), wavy "To-do" underline, ink checkboxes (14×14, 1.4px black border, white fill, blue-ink check on done).
- Bottom-right corner curl: 28×28 triangular gradient suggesting a curled page corner.

**AI Sticky Note** (per-day, optional):
- Position: top-right of page (`top: 16, right: 16`).
- Yellow / green / pink masking-tape note, rotated `±3°-5°`, with sparkles "AI" eyebrow and handwritten message in Caveat 13px.
- **Peelable:** tap to fold to a 22×22 tab that tucks to `top: 4, right: 96` (clear of the date). Tap again to spring back.

**Page-flip animation** (between days):
- 3D rotateY across the spine axis, `0.62s`, `cubic-bezier(0.45, 0.05, 0.55, 0.95)`.
- During flip: front and back faces rendered separately (back is mirrored with `rotateY(180deg)`), both with a shading gradient that animates `0 → 0.55 → 0` opacity.

**Swipe gesture:** horizontal drag > 40px triggers flip in that direction.

### 2. Calendar — Week Page (Hobonichi-style)

**Purpose:** Quick overview of all 7 days on one page.

**Layout:**
- Same paper page chrome (margin, holes, grain, ruled lines).
- Header: "Week N" (Caveat 26px) + range subtitle + event/task counts (right-aligned).
- 7 rows, each: 56px-wide date column (weekday tag in 9px caps + 28px Caveat number) | events column (one line per event with time in 10px Cochin, title in Caveat 15px, category dot 6×6).
- Today's row is gently highlighted with `linear-gradient(90deg, rgba(255,230,128,0.4), rgba(255,230,128,0))`.
- AI summary sticky in bottom-right.

### 3. Review (Paper)

**Purpose:** End-of-week reflection.

**Layout:**
- Same book chrome.
- "Week N · In review" title (Caveat 28px) + completion-rate percent (Caveat 48px, rotated `-3°`).
- AI Summary block in `PAPER.blueInk` Caveat 18px.
- "Time spent" section: dotted-line bar chart, one row per category, bar fill in `PAPER_CATEGORIES[cat].dot` at 55% opacity, hours right-aligned.
- "Notes from AI": ★ bullets in colored ink.
- "Streaks": emoji + Caveat label + 7-day pill row.

### 4. Apple Intelligence Search Overlay (Paper)

**Purpose:** Natural-language search over user's calendar + tasks + inbox, on-device.

**Layout:**
- Slides down from top, `0.32s cubic-bezier(0.2, 0.8, 0.2, 1)`.
- Leather chrome top bar with title "Apple Intelligence" (Caveat 24px) and Close pill.
- Paper sheet (same margin/holes/grain as a day page).
- Input area: 9px caps "Ask" eyebrow with sparkles icon, then a Caveat 22px input field underlined with a 1px ink line. Mic icon on the right.
- Suggested queries: list of "↳ When's my next dentist appointment?" Caveat 18px in blue ink.
- Thinking state: "thinking…" in ink-shimmer gradient (`#1A3A7A` → `#9C2A2A` → `#2C5A2C` → loop, 2.5s).
- Answer: handwritten Caveat 22px in blue ink, then citation chips (yellow `rgba(255,230,128,0.4)` patches with dashed border, category dot, event title in Caveat 15px, weekday/time in 10px system).
- Quick-action pills below the answer.
- Footer micro-copy "Answered on-device · 0.3s".

### 5. Event Detail (Paper "torn-page" sheet)

**Purpose:** View / edit one event, configure reminders.

**Layout:**
- Bottom sheet, slides up with `0.32s` cubic-bezier.
- Cream paper card with a **zigzag torn top edge** (CSS mask SVG, 40×10 zigzag pattern repeating-X).
- Three hole punches across the top, 60px apart.
- Header: category chip (dashed border, dot, name in 9px caps), then event title in Caveat 28px in category ink, then weekday + time range in Caveat 17px ink2.
- Detail rows (separator: `0.5px solid PAPER.rule`):
  - Location: pin icon + "↳ {loc}" in Caveat 18px, "Tap to open in Maps" subtitle.
  - Travel time: car icon + "{n} min".
  - Alert me: bell + "15 minutes before" + paper toggle (38×22, green when on).
  - When I arrive: pin + location + toggle.
  - Invitees: people icon + count + chevron.
- Yellow sticky note inside the sheet with an AI suggestion specific to the event.
- "Tear out this page" delete button: dashed red border, transparent bg, Caveat 17px red ink.

### 6. Week Picker

**Purpose:** Jump to any week without scrolling.

**Layout:**
- Drops down from top when the date-range pill is tapped.
- Mini month grid, 5 months centered on current focus (focus ±2).
- Columns: `[Wxx label] [M T W T F S S]`, each cell shows the day number in Caveat 17px (`PAPER.ink` if in-month, `PAPER.ink3` if not).
- Today is a 24px red filled circle with white number.
- Selected week row has a soft blue tint (`rgba(26,58,122,0.12)`).
- Tap any week → calls `onPick(weekOffset)` and closes.
- "Today" and "Close" pill buttons in the header.

### 7. Settings (Paper bottom sheet)

**Purpose:** Theme, font, size, connections, preferences.

**Layout:**
- Bottom sheet, slides up `0.32s` cubic-bezier.
- Cream paper background with drag handle.
- Sections (each with eyebrow + Caveat title):
  1. **Theme**: 3-column grid of ThemeCards — preview swatch + name + tag. Cream / Kraft / Midnight.
  2. **Handwriting**: 2-column grid of FontCards — "Aa" sample in the font + label. Caveat / Architects Daughter / Kalam / Indie Flower.
  3. **Text size**: segmented S / M / L (using the font itself, sized differently per option).
  4. **Connections**: rows for Gmail (toggleable), Apple Mail (always on), Google Calendar (off). Each row: brand logo + name + status + paper toggle.
  5. **Preferences**: Week starts on (Monday / Sunday), Default reminder (None / 5 / 15 / 30 / 60 min), Apple Intelligence toggle.
  6. About footer: "The Planner · v1.0 · made with care" in italic Caveat.

### 8. Modern Mode (alternative)

A separate fully-styled stock-iOS look (Day / 2-Day / Week, tab bar, system colors). Toggleable in Tweaks → Style. Treat as a fallback theme; same data, modern visuals using SF Pro and system controls.

## Interactions & Behavior

- **Page flip**: tap "Flip forward/back" or swipe horizontally on day page. Crosses week boundaries automatically.
- **Day tabs (M/T/W/T/F/S/S)**: tap any to flip directly.
- **Week stepping**: `‹`/`›` arrows in the header step week-by-week (no flip; instant).
- **Week picker**: tap the date range → calendar grid drops down → tap any week to jump.
- **"Today" pill**: appears only when not on current week. Returns to `weekOffset=0, focusedDay=PP_TODAY.weekdayIdx`.
- **AI sticky note**: tap to peel → folds to 22×22 tab (above the date). Tap again to expand.
- **Event tap**: opens paper event sheet (bottom slide).
- **Task check**: tap circle in to-do block toggles `done`; line-through + dim text.
- **AI search**: pull-down overlay; auto-focus input on open; Enter submits; suggested queries are pre-baked; cite chips close the overlay and open the corresponding event.
- **Theme/font/size changes**: instant; persisted to a tweak block (treat as user preferences in a real app — use UserDefaults / a settings store).
- **Settings tab in bottom bar**: doesn't navigate to a screen — opens the Settings sheet overlay and leaves the current tab active behind it.

## State Management

App-level state (in `app.jsx`):
- `tab`: `'week' | 'review'` — bottom tab
- `viewMode`: `'day' | 'two' | 'week'` — modern mode only
- `paperView`: `'day' | 'week'` — paper mode
- `weekOffset`: integer, 0 = current week (May 11–17, 2026 in the demo). Use a Date offset in real impl.
- `focusedDay`: 0–6, Monday-indexed
- `aiOpen`, `openEventId`, `settingsOpen`: overlay booleans
- `tasks`: array of task objects (local optimistic toggle)
- `gmailConnected`, `reminderDefault`, `weekStart`: settings prefs
- `paperTheme`, `paperFont`, `paperSize`: theme prefs (driving `applyPaperTheme()` which mutates a shared theme object)

In a real implementation:
- Wrap settings in a single `SettingsStore` (UserDefaults-backed in iOS).
- Calendar data should come from EventKit (`EKEventStore`).
- Gmail-sourced events: persist a `source` field; render the Gmail glyph for `source === 'gmail'`.
- AI queries route through the `Foundation Models` framework with a system prompt that knows about the user's events/tasks/notes.

## Design Tokens

### Theme — Cream (default)
```
cream:     #FAF6E9    creamHi:    #FCF9EE    creamLo:    #F1EAD2
rule:      rgba(139,121,80,0.18)
ruleSoft:  rgba(139,121,80,0.08)
redLine:   rgba(192,72,72,0.55)
ink:       #1A1A2A    ink2:       rgba(26,26,42,0.62)    ink3:       rgba(26,26,42,0.34)
blueInk:   #1A3A7A    redInk:     #9C2A2A    greenInk:   #2C5A2C    pencil:     #3A3A55
bookCover: linear-gradient(160deg, #2C2418, #1A1410)
bookSpine: #0F0A06
chromeText:  #E8D9B7    chromeMuted: rgba(232,217,183,0.65)
edgeStripe:  repeating-linear-gradient(180deg, #EFE5C9 0 2px, #E2D6B3 2px 4px)
holePunch:   #E8E0CB
```

### Theme — Kraft
Warm-tan paper variant. See `paper-theme.jsx` for exact values.

### Theme — Midnight
Dark inverted variant. See `paper-theme.jsx` for exact values.

### Category palette
```
work:     dot #0A84FF    personal: dot #BF5AF2    health:   dot #30D158
family:   dot #FF375F    focus:    dot #FF9F0A    travel:   dot #64D2FF
```
Light backgrounds: `rgba(<dot>, 0.12)`. Dark backgrounds: `rgba(<dot>, 0.22)`.

### Typography
- **System**: -apple-system / SF Pro Text — used for tab bar, chrome, micro-copy, settings labels.
- **Serif body**: Cochin / Georgia — used for time gutters, page locations, captions.
- **Handwriting (user-selectable)**:
  - Caveat (default) — Google Fonts, weights 400/500/600/700
  - Architects Daughter — Google Fonts
  - Kalam — Google Fonts, 300/400/700
  - Indie Flower — Google Fonts

Type scale (in handwriting font):
- Page weekday title: 30px / 700
- Page date number: 62px / 700 / rotated `-3°`
- Event titles: 21px / 600
- Task labels: 17px / 500
- Sticky note body: 13px / 600

### Spacing & radius
- Page surface inset: `0 18px 0 26px`
- Page side margin (red line): 32px from left
- Hole-punch column: `left: 8, width: 12, height: 12`
- Card border radius (paper page): `2px 12px 12px 2px`
- Tab bar height: ~76px including 26px safe-area bottom

### Animations
- Page flip: `0.62s cubic-bezier(0.45, 0.05, 0.55, 0.95)`, 3D `rotateY` across spine
- Sheets: `0.32s cubic-bezier(0.2, 0.8, 0.2, 1)`
- Sticky peel: `0.32s cubic-bezier(0.2, 0.8, 0.2, 1.1)` (slight overshoot)
- AI thinking shimmer: `2.5s linear infinite` background-position sweep

## Assets

All visuals are CSS / SVG — no raster assets. Iconography:
- All icons in `icons.jsx` are custom SVGs (calendar, checklist, sparkles, inbox, search, plus, bell, pin, people, clock, car, chevrons, mic, flag, check, circle, share, trash, repeat, edit, settings). In native iOS, prefer SF Symbols (e.g. `bell.fill`, `mappin`, `sparkles`, `gearshape.fill`).
- Brand logos in `paper-settings.jsx`: small Gmail, Apple, Google Calendar SVGs for the Connections section.

Fonts: load from Google Fonts (link in `Weekly Planner.html`) or bundle .ttf/.otf in the iOS app.

## Files

The HTML prototype consists of these files (all included in this handoff):

- `Weekly Planner.html` — Entry point; loads React + all modules.
- `data.jsx` — Mock dataset: events, tasks, inbox suggestions, AI prompts, week helpers.
- `icons.jsx` — Custom SVG icon set.
- `components.jsx` — Modern-mode shared widgets (DayStrip, ViewToggle, TimeGrid, AgendaWeek).
- `screens.jsx` — Modern Week/Tasks screens.
- `review.jsx` — Modern Review screen.
- `overlays.jsx` — Modern AI search overlay, modern event sheet, TabBar.
- `paper-theme.jsx` — Theme registry, font/size options, `applyPaperTheme()` mutator.
- `paper-planner.jsx` — Paper Day + Week pages, side tabs, page-flip mechanics, AI sticky note, week picker, top bar, book chrome.
- `paper-review.jsx` — Paper Review page.
- `paper-overlays.jsx` — Paper AI search overlay + paper event sheet.
- `paper-settings.jsx` — Settings bottom sheet (theme/font/size/connections/preferences).
- `app.jsx` — App root: state, routing, wiring.

## Recommended Implementation Order (SwiftUI)

1. **Foundation**: paper theme object (struct with all colors + font + scale) injected via `@Environment`. Settings store using `@AppStorage`.
2. **Day page** static layout: leather background, paper card, red margin, holes, grain, ruled lines, header with date + weekday, list of event entries.
3. **Event entry rendering**: time gutter + handwriting title + location + Gmail glyph.
4. **Side tabs + page flip**: use `matchedGeometryEffect` or `rotation3DEffect` with a custom transition.
5. **Tasks block + AI sticky note** with peel state.
6. **Week page** (Hobonichi rows).
7. **Top bar** + week picker (calendar grid sheet).
8. **Event detail sheet** with torn-paper top edge (use a `Shape` with zigzag path).
9. **Apple Intelligence overlay** — wire to Foundation Models for real on-device responses.
10. **Settings sheet** + theme switching.
11. **Review page**.

The HTML prototype is the source of truth for visual decisions. When in doubt, run the prototype side-by-side with your SwiftUI build.
