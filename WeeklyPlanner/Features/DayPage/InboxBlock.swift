import SwiftUI

/// "FROM INBOX" section that hangs beneath a day's confirmed events list.
///
/// Layout, top to bottom:
/// 1. A hairline (0.5pt) dashed divider painted across the full width via a
///    `Canvas` — drawing once into the `GraphicsContext` is cheaper than the
///    nested `HStack { ForEach } ` alternative and produces consistent dash
///    spacing on every device scale.
/// 2. A compact eyebrow row pairing the multi-color `GmailGlyph` with the
///    uppercase "FROM INBOX" label in tracked system 8pt.
/// 3. A `LazyVStack` of `InboxSuggestionRow`s sorted ascending by
///    `proposedStart` so suggestions interleave naturally with the events
///    list above when read top-to-bottom.
///
/// Renders nothing when `suggestions` is empty — the caller does not need to
/// gate the block on `inbox.isEmpty` explicitly.
struct InboxBlock: View {
    /// Pending inbox suggestions to surface for this day. The view sorts a
    /// local copy by `proposedStart` ascending; callers can pass any order.
    let suggestions: [InboxSuggestion]

    /// Forwarded to each row's accept button, scoped to that row's
    /// `suggestion.id`. The day-page view model wires this to
    /// `InboxStore.accept(id:)`.
    var onAccept: (UUID) -> Void

    /// Forwarded to each row's dismiss button, scoped to that row's
    /// `suggestion.id`. The day-page view model wires this to
    /// `InboxStore.dismiss(id:)`.
    var onDismiss: (UUID) -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        if suggestions.isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    // MARK: - Subviews

    /// Composes divider + eyebrow + rows. Split out so the outer `body` only
    /// holds the empty-state gate.
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            dashedDivider
                .padding(.top, 6)
                .padding(.bottom, 6)

            eyebrowRow
                .padding(.bottom, 4)

            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(sortedSuggestions, id: \.id) { suggestion in
                    InboxSuggestionRow(suggestion: suggestion,
                                       onAccept: { onAccept(suggestion.id) },
                                       onDismiss: { onDismiss(suggestion.id) })
                }
            }
        }
    }

    /// Full-width 0.5pt dashed line in `theme.ink3`. Drawn inside a
    /// `Canvas` via `Path.strokedPath(StrokeStyle(dash:))` so dash phase and
    /// width are consistent regardless of container size.
    private var dashedDivider: some View {
        Canvas { context, size in
            var path = Path()
            let y = size.height / 2
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            let strokeStyle = StrokeStyle(lineWidth: 0.5, dash: [4, 3])
            context.stroke(path, with: .color(theme.ink3), style: strokeStyle)
        }
        .frame(height: 0.5)
    }

    /// 9pt Gmail glyph + tracked "FROM INBOX" label. Mirrors the eyebrow
    /// styling used elsewhere in the design system (`Typography.eyebrow`)
    /// but at the slightly smaller 8pt size called for in the spec.
    private var eyebrowRow: some View {
        HStack(spacing: 5) {
            GmailGlyph(size: 9)
            Text("FROM INBOX")
                .font(.system(size: 8, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(theme.ink3)
        }
    }

    /// Stable sort key — earliest `proposedStart` first. Returning a new
    /// array (rather than mutating in place) keeps the `body` getter pure
    /// and lets SwiftUI diff cleanly across reloads.
    private var sortedSuggestions: [InboxSuggestion] {
        suggestions.sorted { $0.proposedStart < $1.proposedStart }
    }
}

// MARK: - Previews

#Preview("InboxBlock · Two suggestions") {
    let calendar = WeekMath.mondayCalendar()
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 16

    components.hour = 10
    components.minute = 0
    let tenAM = calendar.date(from: components) ?? Date()

    components.hour = 15
    components.minute = 45
    let threeFortyFive = calendar.date(from: components) ?? Date()

    let suggestions = [
        InboxSuggestion(gmailMessageID: "preview-msg-2",
                        proposedStart: threeFortyFive,
                        title: "Design review with Jin",
                        fromName: "Jin Park",
                        fromEmail: "jin@example.com",
                        category: .work,
                        subject: "Phase 06 review"),
        InboxSuggestion(gmailMessageID: "preview-msg-3",
                        proposedStart: tenAM,
                        title: "Yoga class drop-in",
                        fromName: "Studio Owl",
                        fromEmail: "hello@studioowl.example",
                        category: .health,
                        subject: "10 AM Saturday flow"),
    ]

    return ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                InboxBlock(suggestions: suggestions,
                           onAccept: { _ in },
                           onDismiss: { _ in })
                    .padding(.top, 40)
                    .padding(.leading, 44)
                    .padding(.trailing, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}
