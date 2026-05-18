import SwiftUI

/// Body row inside the Paper Event Detail sheet that surfaces the
/// pre-computed travel time for an event. Populated by the Gmail pipeline
/// (Phase 18) or by manual edits. Static row — no interaction.
///
/// Visibility is the caller's responsibility: `PaperEventSheet` only
/// instantiates this row when `event.travelMinutes != nil`. The 0.5pt
/// bottom separator is drawn by the row itself so the sheet can stack
/// every body row in a `VStack(spacing: 0)`.
struct EventTravelRow: View {
    /// Pre-computed travel time, in minutes.
    let minutes: Int

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "car.fill")
                .font(.system(size: 16))
                .foregroundStyle(theme.ink2)

            Text("Travel time")
                .font(font.font(at: 17, weight: .regular))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(minutes) min")
                .font(.custom("Cochin", size: 13))
                .foregroundStyle(theme.ink2)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.rule)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Travel time \(minutes) minutes")
    }
}

// MARK: - Previews

#Preview("EventTravelRow · Cream") {
    ZStack {
        BookCover()
        EventTravelRow(minutes: 22)
            .padding(.horizontal, 18)
            .background(PaperTheme.cream.cream)
            .padding(40)
    }
    .paperTheme(.cream)
}
