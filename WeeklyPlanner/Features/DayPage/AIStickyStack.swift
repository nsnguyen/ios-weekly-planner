import SwiftUI

struct AIStickyStack: View {
    let insights: [AIInsight]
    let onTap: (AIInsight) -> Void
    let onDismiss: (AIInsight) -> Void
    let onRefresh: () -> Void
    let onNavigate: (Int) -> Void

    @State var currentIndex: Int = 0
    @GestureState private var dragOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PageFlipController.self) private var flipController: PageFlipController?

    private var safeIndex: Int {
        guard !insights.isEmpty else { return 0 }
        return min(currentIndex, insights.count - 1)
    }

    private var currentInsight: AIInsight? {
        guard !insights.isEmpty else { return nil }
        return insights[safeIndex]
    }

    var body: some View {
        if insights.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    ForEach(Array(insights.enumerated()), id: \.element.id) { idx, insight in
                        if idx != safeIndex, peekPosition(of: idx) <= 2, peekPosition(of: idx) > 0 {
                            AIStickyNote(insight: peekInsight(for: insight, at: peekPosition(of: idx)))
                                .allowsHitTesting(false)
                                .offset(peekOffset(at: peekPosition(of: idx)))
                                .opacity(0.92)
                                .zIndex(Double(2 - peekPosition(of: idx)))
                        }
                    }
                    if let top = currentInsight {
                        AIStickyNote(
                            insight: top,
                            onTap: { onTap(top) },
                            onLongPress: { },
                            onRefresh: onRefresh
                        )
                        .zIndex(10)
                        .offset(x: dragOffset)
                        .opacity(dragOpacity)
                        .highPriorityGesture(swipeGesture)
                        .contextMenu {
                            if insights.count > 1 {
                                Button {
                                    navigateForward()
                                } label: {
                                    Label("Show another", systemImage: "arrow.triangle.2.circlepath")
                                }
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
                .animation(AnimationTokens.stickySwipe(reduced: reduceMotion), value: currentIndex)

                if insights.count > 1 {
                    pageIndicator
                }
            }
            .onChange(of: insights.count) { _, newCount in
                if currentIndex >= newCount {
                    currentIndex = max(0, newCount - 1)
                }
            }
        }
    }

    // MARK: - Swipe gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($dragOffset) { value, state, _ in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy) {
                    state = dx
                }
            }
            .onChanged { _ in
                flipController?.stickyDragActive = true
            }
            .onEnded { value in
                flipController?.stickyDragActive = false
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy), abs(dx) > 30 else { return }
                if dx < 0 {
                    navigateForward()
                } else {
                    navigateBackward()
                }
            }
    }

    private var dragOpacity: Double {
        let progress = min(abs(dragOffset) / 120.0, 1.0)
        return 1.0 - (progress * 0.5)
    }

    private func navigateForward() {
        guard insights.count > 1 else { return }
        let next = (safeIndex + 1) % insights.count
        currentIndex = next
        onNavigate(next)
    }

    private func navigateBackward() {
        guard insights.count > 1 else { return }
        let prev = (safeIndex - 1 + insights.count) % insights.count
        currentIndex = prev
        onNavigate(prev)
    }

    // MARK: - Page indicator

    private var pageIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<insights.count, id: \.self) { idx in
                Circle()
                    .fill(idx == safeIndex ? Color.black.opacity(0.4) : Color.clear)
                    .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 0.5))
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityLabel("Page \(safeIndex + 1) of \(insights.count)")
        .accessibilityIdentifier("daypage.sticky.pageIndicator")
    }

    // MARK: - Peek helpers

    private func peekPosition(of idx: Int) -> Int {
        let offset = idx - safeIndex
        if offset > 0 { return offset }
        if offset < 0 { return insights.count + offset }
        return 0
    }

    private func peekInsight(for top: AIInsight, at position: Int) -> AIInsight {
        AIInsight(
            dayKey: top.dayKey,
            dateGenerated: top.dateGenerated,
            text: top.text,
            colorHex: top.colorHex,
            tiltDegrees: top.tiltDegrees - Double(2 * position),
            kind: top.kind,
            priority: top.priority
        )
    }

    private func peekOffset(at position: Int) -> CGSize {
        switch position {
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
