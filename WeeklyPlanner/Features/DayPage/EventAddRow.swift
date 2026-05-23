import SwiftUI

/// Inline "+ add another" affordance rendered below the events + inbox
/// list. The leading glyph is a small dashed-bordered circle with a `+`
/// inside (visually rhyming with the event ink-dots above); the trailing
/// text is an italic gray label that adapts to whether anything has been
/// added to this day yet.
///
/// Used in place of the earlier page-bottom `AddEventLink` — keeping the
/// affordance inline next to the data it adds to makes the empty-state
/// CTA discoverable without a separate "empty page" caption.
struct EventAddRow: View {
    /// `true` when both `events` and `inbox` are empty for this day. Drives
    /// the label copy ("add your first event" vs "add another").
    let isFirstEntry: Bool

    /// Invoked when the user taps the row. Wired to the parent's
    /// "open create-event sheet anchored at this day" handler.
    let onTap: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                dashedCirclePlus
                Text(isFirstEntry ? "add your first event" : "add another")
                    .font(font.font(at: 17 * size.scale, weight: .regular).italic())
                    .foregroundStyle(theme.ink3)
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFirstEntry ? "Add your first event" : "Add another event")
        .accessibilityHint("Opens the new-event composer for this day")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("daypage.events.addRow")
    }

    /// Dashed-bordered circle with a centered `+` glyph. Mirrors the
    /// composer's mock vocabulary: a circle for events, a square for
    /// to-dos (`TodoAddRow`).
    private var dashedCirclePlus: some View {
        ZStack {
            Circle()
                .strokeBorder(theme.ink3,
                              style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: 18, height: 18)
            Image(systemName: "plus")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.ink3)
        }
    }
}

// MARK: - Previews

#Preview("EventAddRow · Both states") {
    ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                VStack(alignment: .leading, spacing: 12) {
                    EventAddRow(isFirstEntry: true, onTap: {})
                    Divider()
                    EventAddRow(isFirstEntry: false, onTap: {})
                }
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
