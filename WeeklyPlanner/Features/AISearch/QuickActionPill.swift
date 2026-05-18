import SwiftUI

/// A pill-style quick action shown below the AI answer body. Renders the
/// `AIAction.title` as a small bold blue-ink label wrapped in a `Capsule`
/// outline — the calmest visual weight available for an interactive label
/// so it doesn't compete with the answer text for attention.
///
/// The button itself is `.buttonStyle(.plain)`: SwiftUI's default highlight
/// would add a fade-out the paper aesthetic doesn't want. Routing is the
/// caller's responsibility — the model only carries the title, so the host
/// view dispatches on `action.id` (e.g. `"directions"` → open Maps).
///
/// Phase 12 wires the chip's tap to the supplied `onTap`. Tap targets remain
/// at SwiftUI's default size; this is intentional — quick actions sit inside
/// a `FlowLayout` row alongside other pills, and growing the hit area would
/// force inter-pill spacing wider than the design allows.
struct QuickActionPill: View {
    /// The action this pill represents. Only its `title` is rendered here;
    /// routing is the caller's responsibility.
    let action: AIAction

    /// Invoked synchronously on the main actor when the user taps the pill.
    var onTap: () -> Void

    @Environment(\.paperTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            Text(action.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.blueInk)
                .padding(EdgeInsets(top: 4, leading: 11, bottom: 4, trailing: 11))
                .background(Color.clear)
                .overlay {
                    Capsule()
                        .strokeBorder(theme.blueInk, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
