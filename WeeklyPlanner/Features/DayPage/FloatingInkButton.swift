import SwiftUI

/// Bottom-trailing floating "+" ink button. Mounted at the AppShell
/// level so Calendar (Day + Week pages) surfaces it; hidden when any
/// sheet/overlay is open via `\.isAnySheetOpen`.
struct FloatingInkButton: View {
    let onTap: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.isAnySheetOpen) private var isAnySheetOpen

    var body: some View {
        if !isAnySheetOpen {
            Button(action: onTap) {
                ZStack {
                    Circle()
                        .fill(theme.cream.opacity(0.96))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(theme.ink, lineWidth: 1.4)
                        )
                        .shadow(color: Color.black.opacity(0.18),
                                radius: 4, x: 0, y: 2)

                    PlusGlyph()
                        .stroke(theme.ink, style: StrokeStyle(lineWidth: 3,
                                                              lineCap: .round))
                        .frame(width: 22, height: 22)
                }
                .contentShape(Rectangle().inset(by: -8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add event")
            .accessibilityHint("Opens new event composer")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("appshell.fab.add")
        }
    }
}

/// Hand-drawn "+" rendered as two perpendicular ink strokes via SwiftUI
/// `Shape`. Slight off-center on the vertical so it reads as inked, not
/// printed.
private struct PlusGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let midX = rect.midX
        path.move(to: CGPoint(x: rect.minX + 1, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX - 1, y: midY))
        path.move(to: CGPoint(x: midX + 0.5, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: midX + 0.5, y: rect.maxY - 1))
        return path
    }
}

// MARK: - Environment key

private struct IsAnySheetOpenKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// True when any modal sheet/overlay is open. Set by `AppShell`.
    var isAnySheetOpen: Bool {
        get { self[IsAnySheetOpenKey.self] }
        set { self[IsAnySheetOpenKey.self] = newValue }
    }
}

/// Observable carrier for "open a fresh create-event sheet anchored
/// at this date". `AppShell` writes, `DayPageContent` reads.
@MainActor
@Observable
final class EventCreationRequest {
    var anchorDate: Date?
    nonisolated init() {}
    func request(at date: Date) { anchorDate = date }
    func consume() { anchorDate = nil }
}

private struct EventCreationRequestKey: EnvironmentKey {
    static let defaultValue: EventCreationRequest = .init()
}

extension EnvironmentValues {
    /// Router that lets the FAB at the AppShell level open a create-event
    /// sheet inside the active Day/Week page.
    var eventCreationRequest: EventCreationRequest {
        get { self[EventCreationRequestKey.self] }
        set { self[EventCreationRequestKey.self] = newValue }
    }
}
