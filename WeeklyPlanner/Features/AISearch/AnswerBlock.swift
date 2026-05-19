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

    /// Surfaced from the view-model. When the case is `.unavailable(...)`
    /// we render the matching short message in place of the on-device
    /// elapsed-time footer, so the user knows why the answer came from
    /// the canned fallback table instead of Apple Intelligence.
    var unavailableReason: AvailabilityState = .available

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

            Text(Self.cleanBody(answer.body))
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

            footer
                .padding(.top, 18)
        }
        .padding(.top, 8)
    }

    /// The system prompt asks the model for plain text, but the model still
    /// occasionally returns markdown asterisks, leading dashes, or headers.
    /// We strip those before display so the handwriting font doesn't render
    /// literal `**` markers on the page. Newlines and word order stay intact.
    static func cleanBody(_ raw: String) -> String {
        var text = raw
        // Strip bold/italic markers.
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "__", with: "")
        // Strip stray solo asterisks/underscores used as italic markers.
        text = text.replacingOccurrences(of: "*", with: "")
        // Strip leading list-bullet dashes and stars at the start of lines.
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            var s = String(line)
            // Drop leading whitespace then a bullet marker like "-", "*", "•".
            let trimmed = s.drop(while: { $0 == " " || $0 == "\t" })
            if let first = trimmed.first, "-•".contains(first) {
                s = String(trimmed.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: " "))
            } else {
                s = String(trimmed)
            }
            // Strip leading markdown header markers ("#", "##", ...).
            while s.hasPrefix("#") { s.removeFirst() }
            return s.trimmingCharacters(in: CharacterSet(charactersIn: " "))
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Either the on-device elapsed-time footer (happy path) or the
    /// availability-state fallback message (Settings off, simulator,
    /// older device). Both render in the same ink-3 italic micro-type so
    /// the layout doesn't reflow when the user toggles AI in Settings.
    @ViewBuilder
    private var footer: some View {
        if unavailableReason.isAvailable {
            Text("Answered on-device · \(String(format: "%.1f", answer.elapsedSeconds))s")
                .font(.system(size: 9, weight: .regular).italic())
                .foregroundStyle(theme.ink3)
        } else {
            Text(unavailableReason.fallbackMessage)
                .font(.system(size: 9, weight: .regular).italic())
                .foregroundStyle(theme.ink3)
        }
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
