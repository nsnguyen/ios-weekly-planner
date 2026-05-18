import SwiftUI

/// Body row inside the Paper Event Detail sheet that drives the geofenced
/// "When I arrive" reminder. Mirrors `EventAlertRow` in shape — pin icon +
/// handwriting label + sublabel + compact `PaperToggle` — but disables the
/// toggle when `location` is nil since there's nothing to geofence.
///
/// The sublabel narrates the current state: `"at {location}"` when the
/// reminder is on, `"Off"` when off, and `"Add a location first"` when
/// `location` is nil. Like the sibling row, the 0.5pt bottom separator is
/// painted by the row itself so it stacks cleanly in a `VStack(spacing: 0)`.
struct EventLocationAlertRow: View {
    /// Two-way binding to the location-alert-on flag. Driven by the view
    /// model.
    @Binding var isOn: Bool

    /// Free-text location string from the event. `nil` disables the toggle
    /// and swaps the sublabel for an "Add a location first" hint.
    let location: String?

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "location.fill")
                .font(.system(size: 16))
                .foregroundStyle(theme.ink2)

            VStack(alignment: .leading, spacing: 0) {
                Text("When I arrive")
                    .font(font.font(at: 17, weight: .regular))
                    .foregroundStyle(theme.ink)

                Text(sublabel)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PaperToggle(isOn: $isOn, style: .compact)
                .disabled(location == nil)
                .opacity(location == nil ? 0.4 : 1)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.rule)
                .frame(height: 0.5)
        }
    }

    /// Sublabel copy mirroring the three logical states the row can be in.
    private var sublabel: String {
        guard let location else { return "Add a location first" }
        return isOn ? "at \(location)" : "Off"
    }
}

// MARK: - Previews

#Preview("EventLocationAlertRow · Cream") {
    EventLocationAlertRowPreviewHost()
        .paperTheme(.cream)
}

/// Internal preview host so the toggle animates in the Xcode canvas.
private struct EventLocationAlertRowPreviewHost: View {
    @State private var withLocationOn = true
    @State private var withoutLocationOn = false

    var body: some View {
        ZStack {
            BookCover()
            VStack(spacing: 24) {
                EventLocationAlertRow(isOn: $withLocationOn, location: "Trick Dog")
                EventLocationAlertRow(isOn: $withoutLocationOn, location: nil)
            }
            .padding(.horizontal, 18)
            .background(PaperTheme.cream.cream)
            .padding(40)
        }
    }
}
