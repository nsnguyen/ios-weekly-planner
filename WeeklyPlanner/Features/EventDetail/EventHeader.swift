import SwiftUI

/// Top section of the Paper Event Detail sheet. Shows the category pill,
/// handwriting title (inked in the event's category color), and the time
/// range line, plus a small `×` close button in the top-right corner.
///
/// All numeric values mirror the spec in
/// `docs/phases/phase-11-event-detail-sheet.md`. Tokens flow in from
/// `@Environment(\.paperTheme)` / `\.paperFont`; the only hardcoded values are
/// the 5×5 dot size, the 9pt eyebrow size, and the close-button glyph size —
/// each of which the spec explicitly fixes.
struct EventHeader: View {
    /// The event being displayed. Drives every text and color decision in
    /// the header.
    let event: Event

    /// Invoked when the user taps the `×` close affordance. The sheet root
    /// uses this to set `isOpen = false`.
    var onClose: () -> Void

    /// Optional callback for promoting the sheet from `.view` to `.edit`.
    /// When non-nil, the header renders an "Edit" link in the trailing
    /// edge left of the close `×`. Nil in `.edit`/`.create` modes and in
    /// previews/tests that don't need the affordance.
    var onEdit: (() -> Void)?

    init(event: Event,
         onClose: @escaping () -> Void,
         onEdit: (() -> Void)? = nil)
    {
        self.event = event
        self.onClose = onClose
        self.onEdit = onEdit
    }

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        // Phase 29 (15): the header sits on a faint tinted band with a hairline
        // rule beneath it, so the title block reads as clearly separated from
        // the body rows below (TestFlight feedback: header blended into the
        // form). The tint is a translucent ink wash that works on every theme.
        HStack(alignment: .top, spacing: 10) {
            leftColumn
                .accessibilityElement(children: .combine)
                .accessibilityLabel(AccessibilityFormatters.eventLabel(event))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if let onEdit {
                editButton(onEdit: onEdit)
                    .padding(.trailing, 6)
            }
            closeButton
        }
        .padding(EdgeInsets(top: 38, leading: 44, bottom: 16, trailing: 18))
        .background(theme.ink.opacity(0.035))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.ink.opacity(0.12))
                .frame(height: 0.5)
        }
    }

    // MARK: - Left column

    /// Category chip + title + time range, stacked tightly so the chip's
    /// `marginBottom: 6` lands directly above the title without a `spacing`
    /// from `VStack` competing with it.
    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            categoryChip
                .padding(.bottom, 6)

            Text(event.title)
                .font(font.font(at: 32, weight: .bold))
                .lineSpacing(1.05)
                .foregroundStyle(CategoryPalette.inkColor(event.category, in: theme))

            Text(Self.timeLine(for: event))
                .font(font.font(at: 17, weight: .regular))
                .foregroundStyle(theme.ink2)
                .padding(.top, 3)
        }
    }

    /// The small chip with a category dot and uppercased category name.
    /// Background and stroke are the spec values — translucent black tint
    /// over the cream paper, plus a 0.5pt `ink3` outline.
    private var categoryChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(CategoryPalette.dot(event.category))
                .frame(width: 5, height: 5)

            Text(CategoryPalette.displayName(event.category).uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(theme.ink2)
        }
        .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        .background(Color.black.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 2)
            .stroke(theme.ink3, lineWidth: 0.5))
    }

    // MARK: - Close button

    /// Small `×` glyph in `ink2`. `.contentShape(...)` extends the hit area
    /// 8pt in every direction so the tap target is the standard 32pt-ish
    /// square even though the glyph itself is only 14pt.
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.ink2)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle().inset(by: -8))
        .accessibilityLabel("Close")
    }

    /// "Edit" link rendered in the trailing edge of the header when
    /// `onEdit` is supplied. Handwriting, bold, blue ink, underlined —
    /// matches the design system's link affordance.
    private func editButton(onEdit: @escaping () -> Void) -> some View {
        Button(action: onEdit) {
            Text("Edit")
                .font(font.font(at: 15, weight: .bold))
                .underline()
                .foregroundStyle(theme.blueInk)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle().inset(by: -8))
        .accessibilityLabel("Edit event")
        .accessibilityHint("Switches the sheet to edit mode")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("paperEventSheet.edit")
    }

    // MARK: - Time formatting

    /// Builds the time line `"Saturday · 8 PM – 11 PM"`. Weekday is
    /// `"EEEE"` in `en_US_POSIX`; the time labels reuse
    /// `EventEntryRow.timeLabel(for:)` so this view never invents its own
    /// formatter.
    static func timeLine(for event: Event) -> String {
        let weekday = Self.weekdayFormatter.string(from: event.start)
        let startLabel = EventEntryRow.timeLabel(for: event.start)
        let endLabel = EventEntryRow.timeLabel(for: event.end)
        return "\(weekday) · \(startLabel) – \(endLabel)"
    }

    /// `"Saturday"`, `"Monday"`, … — full weekday name, locale-independent.
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Previews

#Preview("EventHeader · Cream") {
    let calendar = WeekMath.mondayCalendar()
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 16
    components.hour = 20
    let eightPM = calendar.date(from: components) ?? Date()
    let elevenPM = calendar.date(byAdding: .hour, value: 3, to: eightPM) ?? eightPM
    let event = Event(title: "Sara's birthday",
                      start: eightPM,
                      end: elevenPM,
                      category: .family)

    return ZStack {
        BookCover()
        EventHeader(event: event, onClose: {})
            .background(PaperTheme.cream.cream)
            .padding(40)
    }
    .paperTheme(.cream)
}
