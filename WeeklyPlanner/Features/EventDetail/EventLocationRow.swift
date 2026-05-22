import SwiftUI

/// Body row inside the Paper Event Detail sheet that surfaces the event's
/// physical location. Tapping the row opens Apple Maps with the location as
/// a free-text query (via `MapsLinker.open(query:)`).
///
/// Visibility is the caller's responsibility — this row assumes `location`
/// is non-nil and renders the pin glyph + handwriting address + "Tap to
/// open in Maps" subtitle + trailing chevron. The 0.5pt bottom separator
/// is drawn by the row itself so each body row in the sheet can be stacked
/// in a `VStack(spacing: 0)` without the caller managing dividers.
struct EventLocationRow: View {
    /// The free-text location string from the event. Forwarded verbatim to
    /// `MapsLinker.open(query:)` on tap.
    let location: String

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        Button {
            MapsLinker.open(query: location)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 16))
                    .foregroundStyle(theme.ink2)

                VStack(alignment: .leading, spacing: 0) {
                    Text("\u{21B3} \(location)")
                        .font(font.font(at: 18, weight: .regular))
                        .foregroundStyle(theme.ink)

                    Text("Tap to open in Maps")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.ink3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.ink3)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.rule)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Location: \(location). Tap to open in Maps.")
    }
}

// MARK: - Previews

#Preview("EventLocationRow · Cream") {
    ZStack {
        BookCover()
        EventLocationRow(location: "Trick Dog, Mission, San Francisco")
            .padding(.horizontal, 18)
            .background(PaperTheme.cream.cream)
            .padding(40)
    }
    .paperTheme(.cream)
}
