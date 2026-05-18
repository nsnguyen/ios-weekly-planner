import SwiftUI

/// Body row inside the Paper Event Detail sheet that drives the
/// time-based "alert me" reminder. The bell icon + handwriting label sit
/// on the leading edge; a compact `PaperToggle` is pinned to the trailing
/// edge. A 0.5pt rule is drawn under the row by the row itself so the
/// sheet can stack body rows in a `VStack(spacing: 0)`.
///
/// `isOn` is two-way bound to the view-model's `alertOn`; toggling fires a
/// side-effect on the parent (`viewModel.toggleAlert(_:)`) via the
/// binding's setter — this row does not own the persistence policy.
struct EventAlertRow: View {
    /// Two-way binding to the alert-on flag. Driven by the view model.
    @Binding var isOn: Bool

    /// Minutes-before value shown in the sublabel when `isOn` is `true`.
    /// 15 by default — the view model owns the actual default.
    let minutes: Int

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 16))
                .foregroundStyle(theme.ink2)

            VStack(alignment: .leading, spacing: 0) {
                Text("Alert me")
                    .font(font.font(at: 17, weight: .regular))
                    .foregroundStyle(theme.ink)

                Text(isOn ? "\(minutes) minutes before" : "Off")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PaperToggle(isOn: $isOn, style: .compact)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.rule)
                .frame(height: 0.5)
        }
    }
}

// MARK: - Previews

#Preview("EventAlertRow · Cream") {
    EventAlertRowPreviewHost()
        .paperTheme(.cream)
}

/// Internal preview host that wires `@State` so the toggle animates in
/// the Xcode canvas.
private struct EventAlertRowPreviewHost: View {
    @State private var isOn = false

    var body: some View {
        ZStack {
            BookCover()
            EventAlertRow(isOn: $isOn, minutes: 15)
                .padding(.horizontal, 18)
                .background(PaperTheme.cream.cream)
                .padding(40)
        }
    }
}
