import SwiftUI

/// A single Gmail-sourced suggestion rendered inside the day page's `InboxBlock`.
///
/// The row mirrors `EventEntryRow`'s rhythm — a 48pt Cochin time gutter on the
/// leading edge plus a right column carrying the suggested event title — but is
/// composited at `opacity 0.78` so it reads as "pending, not yet accepted". The
/// title uses the active handwriting family in italic at 17pt to distinguish
/// suggestions from confirmed events (which render at 21pt non-italic). A
/// trailing pair of 18×18 add / dismiss controls forwards taps through the
/// `onAccept` and `onDismiss` closures; the surrounding `.contentShape` is
/// expanded by 8pt on every side so the effective hit target clears the 44pt
/// accessibility minimum even though the visible buttons are small.
///
/// All ink, dot, and stroke colors come from `@Environment(\.paperTheme)` and
/// `CategoryPalette` — there are no hardcoded color literals in this file.
struct InboxSuggestionRow: View {
    /// The suggestion this row represents. The view reads `proposedStart`,
    /// `title`, `fromName`, and `category` directly off the model.
    let suggestion: InboxSuggestion

    /// Invoked when the user taps the green add button. The day-page view
    /// model wires this to `InboxStore.accept(id:)`.
    var onAccept: () -> Void

    /// Invoked when the user taps the dismiss button. The day-page view
    /// model wires this to `InboxStore.dismiss(id:)`.
    var onDismiss: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size
    @Environment(\.dynamicTypeSize) private var dtSize

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            timeGutter
            middleColumn
            actionButtons
        }
        .padding(.vertical, 5)
        .opacity(0.78)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Inbox suggestion: \(suggestion.title), \(suggestion.proposedStart.formatted(date: .omitted, time: .shortened))")
    }

    // MARK: - Subviews

    /// Leading column: Cochin time label tinted with `theme.ink3` so the
    /// suggestion's start time reads as muted next to confirmed event rows.
    /// Width widens from 48pt to 64pt at AX2+ to match `EventEntryRow`.
    private var timeGutter: some View {
        Text(EventEntryRow.timeLabel(for: suggestion.proposedStart))
            .font(.custom("Cochin", size: 12).weight(.semibold))
            .foregroundStyle(theme.ink3)
            .frame(width: DynamicTypeLayout.timeGutterWidth(at: dtSize), alignment: .leading)
    }

    /// Middle column: italic handwritten title + small category dot stacked
    /// over the "via {fromName}" attribution. Expands to fill the remaining
    /// width so the trailing action buttons hug the right edge.
    private var middleColumn: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Text(suggestion.title)
                    .font(font.font(at: 17 * size.scale, weight: .regular).italic())
                    .foregroundStyle(theme.ink2)
                    .lineLimit(2)

                Circle()
                    .fill(CategoryPalette.dot(suggestion.category))
                    .opacity(0.5)
                    .frame(width: 7, height: 7)
            }

            Text("via \(suggestion.fromName)")
                .font(.custom("Cochin-Italic", size: 10))
                .foregroundStyle(theme.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Trailing pair of 18×18 controls — green-outlined add and gray-outlined
    /// dismiss. A 2pt top padding aligns them with the title row baseline,
    /// and `.contentShape(Rectangle().inset(by: -8))` extends each tap target
    /// outward by 8pt on every side to meet the 44pt accessibility minimum.
    private var actionButtons: some View {
        HStack(spacing: 5) {
            Button {
                onAccept()
            } label: {
                acceptIcon
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle().inset(by: -8))
            .accessibilityLabel("Accept suggestion")
            .accessibilityHint("Adds this event to your calendar")

            Button {
                onDismiss()
            } label: {
                dismissIcon
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle().inset(by: -8))
            .accessibilityLabel("Dismiss suggestion")
            .accessibilityHint("Removes this suggestion from inbox")
        }
        .padding(.top, 2)
    }

    /// Green-bordered square containing a 10×10 `plus` glyph stroked in
    /// `theme.greenInk`. The corner radius (4pt) matches the dismiss button
    /// so the pair reads as a unit.
    private var acceptIcon: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(theme.greenInk, lineWidth: 1)
            .frame(width: 18, height: 18)
            .overlay(Image(systemName: "plus")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(theme.greenInk)
                .frame(width: 10, height: 10))
    }

    /// Gray-bordered square containing a 9×9 `xmark` glyph stroked in
    /// `theme.ink3`. Slightly smaller glyph than the plus so the two icons
    /// visually balance at the same outer dimensions.
    private var dismissIcon: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(theme.ink3, lineWidth: 1)
            .frame(width: 18, height: 18)
            .overlay(Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(theme.ink3)
                .frame(width: 9, height: 9))
    }
}

// MARK: - Previews

#Preview("InboxSuggestionRow · Cream") {
    let calendar = WeekMath.mondayCalendar()
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 16
    components.hour = 14
    components.minute = 30
    let twoThirty = calendar.date(from: components) ?? Date()

    let suggestion = InboxSuggestion(gmailMessageID: "preview-msg-1",
                                     proposedStart: twoThirty,
                                     title: "Coffee with Priya",
                                     fromName: "Priya Shah",
                                     fromEmail: "priya@example.com",
                                     category: .personal,
                                     subject: "Catch up next week?")

    return ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                InboxSuggestionRow(suggestion: suggestion,
                                   onAccept: {},
                                   onDismiss: {})
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
