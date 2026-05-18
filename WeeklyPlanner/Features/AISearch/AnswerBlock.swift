import SwiftUI

/// State C of the AI search overlay: the rendered answer. Stacks the echoed
/// query, the handwritten body, optional citation chips, optional quick
/// actions, and an "Answered on-device · 0.3s" footer in that order.
///
/// Each section appears conditionally (citations / actions are hidden when
/// the underlying arrays are empty), so an answer with neither still reads
/// as a clean Q-and-A pair without empty spacers eating the visual rhythm.
///
/// Citation and action chips wrap via the in-file `FlowLayout` — a minimal
/// flex-wrap port of CSS `flex-wrap: wrap`. The layout walks the subviews
/// once at `sizeThatFits` time and again at `placeSubviews`, breaking to a
/// new row whenever the current row would exceed the proposed width. That's
/// expensive for thousands of children, but here we cap at 3 citations + 3
/// actions so it's effectively free.
struct AnswerBlock: View {
    /// The answer to render. Owned by the view-model and pre-resolved by
    /// `AISearchViewModel.ask(text:)` before being assigned.
    let answer: AIAnswer

    /// Invoked when the user taps any citation chip. The host is expected to
    /// close the overlay and then open the matching event detail sheet
    /// 100ms later (per the Phase 12 spec).
    var onTapCitation: (UUID) -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Q · \(answer.query)")
                .font(font.font(at: 16, weight: .regular).italic())
                .foregroundStyle(theme.ink2)
                .padding(.bottom, 6)

            Text(answer.body)
                .font(font.font(at: 22, weight: .semibold))
                .lineSpacing(1.3)
                .tracking(0.1)
                .foregroundStyle(theme.blueInk)

            if !answer.citations.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(answer.citations) { citation in
                        CitationChip(citation: citation) {
                            onTapCitation(citation.id)
                        }
                    }
                }
                .padding(.top, 12)
            }

            if !answer.actions.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(answer.actions) { action in
                        QuickActionPill(action: action) {
                            // Routing for quick actions lands in Phase 13 —
                            // each action's `id` will dispatch to its own
                            // handler (Maps, Reminders, Mail, …). For Phase
                            // 12 the pill is visually wired but the tap is
                            // intentionally inert.
                        }
                    }
                }
                .padding(.top, 12)
            }

            Text("Answered on-device · \(String(format: "%.1f", answer.elapsedSeconds))s")
                .font(.system(size: 9, weight: .regular).italic())
                .foregroundStyle(theme.ink3)
                .padding(.top, 18)
        }
        .padding(.top, 8)
    }
}

/// Minimal flex-wrap layout for citation chips and quick-action pills.
///
/// Walks subviews in order, placing each one at the current `x` cursor and
/// wrapping to the next row whenever a subview would overflow the proposed
/// width. Each row's height is the tallest subview placed in it. There is
/// no per-row baseline alignment — children are top-aligned within their
/// row, which is what the spec wants for paired chip/pill rows.
///
/// `FlowLayout` deliberately doesn't cache its measurements: the chip /
/// pill rows in the AI overlay are tiny (≤ 6 subviews) and rebuild every
/// answer, so a cache would cost more bookkeeping than it saves.
struct FlowLayout: Layout {
    /// Horizontal gap between sibling items AND vertical gap between rows.
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                       proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
