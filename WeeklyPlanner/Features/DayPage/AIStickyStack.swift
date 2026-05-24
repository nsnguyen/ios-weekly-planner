import SwiftUI

/// Cascade renderer for Phase 24's AI sticky-note insights. Up to 3
/// `AIStickyNote`s stacked at the top-right of the Day page, with the
/// top one full-size and behind-stickies offset/tilted so a paper-peek
/// peeks out behind it.
struct AIStickyStack: View {
    let insights: [AIInsight]
    let onTap: (AIInsight) -> Void
    let onDismiss: (AIInsight) -> Void
    let onRefresh: () -> Void
    let onShowAnother: () -> Void

    var body: some View {
        if insights.isEmpty {
            EmptyView()
        } else {
            ZStack(alignment: .topTrailing) {
                ForEach(Array(insights.enumerated()), id: \.element.id) { idx, insight in
                    if idx > 0, idx <= 2 {
                        AIStickyNote(insight: peekInsight(for: insight, at: idx))
                            .allowsHitTesting(false)
                            .offset(peekOffset(at: idx))
                            .opacity(0.92)
                            .zIndex(Double(2 - idx))
                    }
                }
                if let top = insights.first {
                    AIStickyNote(
                        insight: top,
                        onTap: { onTap(top) },
                        onLongPress: { /* context menu attaches separately */ },
                        onRefresh: onRefresh
                    )
                    .zIndex(10)
                    .contextMenu {
                        Button {
                            onShowAnother()
                        } label: {
                            Label("Show another", systemImage: "arrow.triangle.2.circlepath")
                        }
                        Button(role: .destructive) {
                            onDismiss(top)
                        } label: {
                            Label("Dismiss this insight", systemImage: "xmark.circle")
                        }
                        Button {
                            onRefresh()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        if let actionLabel = actionLabel(for: top.kind) {
                            Button {
                                onTap(top)
                            } label: {
                                Label(actionLabel, systemImage: actionIcon(for: top.kind))
                            }
                        }
                    }
                    .accessibilityIdentifier("daypage.sticky.top")
                }
            }
        }
    }

    private func peekInsight(for top: AIInsight, at idx: Int) -> AIInsight {
        let copy = AIInsight(
            dayKey: top.dayKey,
            dateGenerated: top.dateGenerated,
            text: top.text,
            colorHex: top.colorHex,
            tiltDegrees: top.tiltDegrees - Double(2 * idx),
            kind: top.kind,
            priority: top.priority
        )
        return copy
    }

    private func peekOffset(at idx: Int) -> CGSize {
        switch idx {
        case 1: return CGSize(width: -4, height: 8)
        case 2: return CGSize(width: -8, height: 14)
        default: return .zero
        }
    }

    private func actionLabel(for kind: InsightKind) -> String? {
        switch kind {
        case .travel: return "Get directions"
        case .weather: return "Open Weather"
        case .keyword: return "Open event"
        case .inbox: return "Open inbox"
        case .encouragement: return nil
        }
    }

    private func actionIcon(for kind: InsightKind) -> String {
        switch kind {
        case .travel: return "map"
        case .weather: return "cloud.rain"
        case .keyword: return "calendar"
        case .inbox: return "tray"
        case .encouragement: return "sparkles"
        }
    }
}
