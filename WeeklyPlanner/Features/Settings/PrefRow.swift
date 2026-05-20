import SwiftUI

/// Expandable preference row. Tap the value chevron → expands to a wrap-row
/// of option pills, one of which is highlighted with the blueInk border +
/// 10% fill. Selecting a pill calls `onSelect` and collapses the row.
///
/// Uses 0.22s ease for the chevron rotation + reveal (per Phase 16 spec).
struct PrefRow<Option: Hashable & CustomStringConvertible>: View {
    let label: String
    let value: Option
    let options: [Option]
    let onSelect: (Option) -> Void

    @Environment(\.paperTheme) private var theme
    @State private var isOpen: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(describing: value))
                        .font(.system(size: 14))
                        .foregroundStyle(theme.ink2)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.ink3)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            }
            .buttonStyle(.plain)

            if isOpen {
                optionsRow
                    .padding(EdgeInsets(top: 0, leading: 14, bottom: 10, trailing: 14))
                    .transition(.opacity)
            }
        }
    }

    private var optionsRow: some View {
        WrappingHStack(spacing: 6, lineSpacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                    withAnimation(.easeInOut(duration: 0.22)) { isOpen = false }
                } label: {
                    Text(String(describing: option))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .padding(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
                        .background(
                            Capsule().fill(option == value
                                ? theme.blueInk.opacity(0.10)
                                : Color.clear)
                        )
                        .overlay(
                            Capsule().strokeBorder(option == value
                                ? theme.blueInk
                                : theme.rule,
                                lineWidth: option == value ? 1.0 : 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Flow layout that wraps subviews to the next line when they overflow the
/// container width. Used by `PrefRow` so the 5-option Default-reminder list
/// (None / 5 min / 15 min / 30 min / 1 hr) wraps cleanly on narrow widths
/// instead of compressing into a single overflowing row.
struct WrappingHStack: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let lines = layoutLines(maxWidth: maxWidth, subviews: subviews)
        let height = lines.reduce(CGFloat(0)) { $0 + $1.height } +
            CGFloat(max(0, lines.count - 1)) * lineSpacing
        let width = lines.map(\.width).max() ?? 0
        return CGSize(width: min(maxWidth, width), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let maxWidth = proposal.width ?? bounds.width
        let lines = layoutLines(maxWidth: maxWidth, subviews: subviews)
        var y = bounds.minY
        for line in lines {
            var x = bounds.minX
            for entry in line.entries {
                subviews[entry.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(entry.size)
                )
                x += entry.size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Entry {
        let index: Int
        let size: CGSize
    }

    private struct Line {
        var entries: [Entry] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layoutLines(maxWidth: CGFloat, subviews: Subviews) -> [Line] {
        var lines: [Line] = []
        var current = Line()
        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            let needsBreak = !current.entries.isEmpty
                && current.width + spacing + size.width > maxWidth
            if needsBreak {
                lines.append(current)
                current = Line()
            }
            if current.entries.isEmpty {
                current.width = size.width
            } else {
                current.width += spacing + size.width
            }
            current.height = max(current.height, size.height)
            current.entries.append(Entry(index: i, size: size))
        }
        if !current.entries.isEmpty { lines.append(current) }
        return lines
    }
}
