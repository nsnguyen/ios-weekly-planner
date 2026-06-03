import SwiftUI

struct AIStickyStack: View {
    let insights: [AIInsight]
    let onTap: (AIInsight) -> Void
    let onDismiss: (AIInsight) -> Void
    let onRefresh: () -> Void
    let onNavigate: (Int) -> Void

    @State var currentIndex: Int = 0
    @GestureState private var dragOffset: CGFloat = 0
    /// Gesture-state-backed "a sticky drag is in progress" truth. Unlike a
    /// manual flag, SwiftUI guarantees `@GestureState` resets to `false` when
    /// the gesture ends, is cancelled, OR the view hosting it is torn down
    /// mid-drag. We mirror this onto the shared controller via `.onChange`
    /// below so the page-flip suppression can never strand `true` (Phase 28 —
    /// the swipe-lock fix). The previous code set the controller flag directly
    /// in `.onChanged`/`.onEnded`, and a refresh/tick/dismiss mid-drag could
    /// skip `.onEnded`, leaving navigation permanently suppressed.
    @GestureState private var isDragging: Bool = false
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
                // If the cascade empties mid-drag (dismiss / toggle off), the
                // sticky disappears; make sure we're not still suppressing the
                // page flip.
                if newCount == 0 {
                    flipController?.stickyDragActive = false
                }
            }
            // Mirror the gesture-state truth onto the shared controller. This
            // is the interruption-proof reset: `isDragging` returns to `false`
            // automatically on gesture end/cancel/teardown, and this fires the
            // controller clear even when `.onEnded` would have been skipped.
            .onChange(of: isDragging) { _, dragging in
                flipController?.stickyDragActive = dragging
            }
            // Final safety net: leaving the page (Day→Week, tab switch) while a
            // drag is somehow still marked active must never leave navigation
            // locked on the shared controller.
            .onDisappear {
                flipController?.stickyDragActive = false
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
            // `isDragging` is held true for the life of the gesture and reset
            // automatically by SwiftUI when it ends/cancels/tears down. The
            // `.onChange(of: isDragging)` above turns that into the controller
            // flag — no manual reset that a skipped `.onEnded` could drop.
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onEnded { value in
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
