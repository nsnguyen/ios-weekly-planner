import SwiftUI

/// Body row inside the Paper Event Detail sheet that surfaces the number
/// of invitees on an event. v1 is read-only — there's no detail view to
/// drill into yet — so the trailing chevron is rendered at 40% opacity and
/// the row carries no tap action, signalling "coming soon" without a
/// disabled-state grey wash.
///
/// Visibility is the caller's responsibility: `PaperEventSheet` only
/// instantiates this row when `event.attendeesCount > 1`. The 0.5pt
/// bottom separator is drawn by the row so it stacks cleanly in a
/// `VStack(spacing: 0)`.
struct EventInviteesRow: View {
    /// Number of attendees, including the user. The label uses the raw
    /// count without subtracting "you" — matching the mock copy.
    let attendeesCount: Int

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 16))
                .foregroundStyle(theme.ink2)

            Text("Invitees")
                .font(font.font(at: 17, weight: .regular))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(attendeesCount) people")
                .font(.custom("Cochin", size: 13))
                .foregroundStyle(theme.ink2)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.ink3)
                .opacity(0.4)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.rule)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(attendeesCount) invitee\(attendeesCount == 1 ? "" : "s")")
    }
}

// MARK: - Previews

#Preview("EventInviteesRow · Cream") {
    ZStack {
        BookCover()
        EventInviteesRow(attendeesCount: 4)
            .padding(.horizontal, 18)
            .background(PaperTheme.cream.cream)
            .padding(40)
    }
    .paperTheme(.cream)
}
