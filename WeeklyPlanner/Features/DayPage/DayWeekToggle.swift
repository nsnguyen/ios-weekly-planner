import SwiftUI

/// Two-segment chrome toggle that lets the user pick between the Day and
/// Week spreads. Always rendered on the planner's top bar (over the dark
/// leather cover), so the off-state ink color is theme-tinted chrome rather
/// than page ink.
///
/// Geometry: a rounded-7pt capsule whose inner 2pt padding wraps two segments
/// separated by a 2pt gap. The outer ring is a 0.5pt translucent white border
/// and a `Color.black.opacity(0.3)` fill so the control reads as a subtle
/// inset notch on the leather. Active segments get a `theme.chromeText` fill
/// with `theme.bookSpine` text; inactive ones stay transparent with
/// `theme.chromeText` text.
///
/// The toggle sizes itself intrinsically (no fixed outer frame) so the
/// "Day" / "Week" labels render fully at 11pt system semibold; the JS mock's
/// 62×24 outer frame was authored at a different DPI and clipped the labels
/// on iOS. Expect ~76-84pt wide × ~24-26pt tall in practice.
struct DayWeekToggle: View {
    /// Currently selected view. Two-way bound so taps mutate the parent's
    /// `PaperView` state directly.
    @Binding var selection: PaperView

    @Environment(\.paperTheme) private var theme

    var body: some View {
        HStack(spacing: 2) {
            segment(for: .day, label: "Day")
            segment(for: .week, label: "Week")
            segment(for: .review, label: "Review")
        }
        .padding(2)
        .background(Color.black.opacity(0.3),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("View")
        .accessibilityValue({
            switch selection {
            case .day: return "Day"
            case .week: return "Week"
            case .review: return "Review"
            }
        }())
        .accessibilityAddTraits(.isButton)
    }

    /// Renders one of the two segments. `active` flips both the fill and the
    /// text color via the theme tokens; the inactive segment uses a fully
    /// transparent fill so the outer well shows through.
    private func segment(for value: PaperView, label: String) -> some View {
        let active = selection == value
        return Button {
            selection = value
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(active ? theme.bookSpine : theme.chromeText)
                .padding(.vertical, 3)
                .padding(.horizontal, 12)
                .background(active ? theme.chromeText : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("DayWeekToggle · both states") {
    DayWeekTogglePreviewHost()
        .paperTheme(.cream)
}

#Preview("DayWeekToggle · midnight") {
    DayWeekTogglePreviewHost()
        .paperTheme(.midnight)
}

/// Preview host that wires the binding to local `@State` so the segment
/// switch can be exercised live in the canvas.
private struct DayWeekTogglePreviewHost: View {
    @State private var dayActive: PaperView = .day
    @State private var weekActive: PaperView = .week

    var body: some View {
        ZStack {
            BookCover()
            VStack(spacing: 24) {
                DayWeekToggle(selection: $dayActive)
                DayWeekToggle(selection: $weekActive)
            }
            .padding(40)
        }
    }
}
