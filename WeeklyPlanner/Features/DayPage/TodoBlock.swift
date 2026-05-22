import SwiftUI

/// Dashed yellow patch at the bottom of a Day page that lists the day's
/// to-dos. Renders nothing when `tasks` is empty, so callers can drop it
/// into the page composition without gating on `.isEmpty` themselves.
///
/// Layout:
/// 1. A header reading `"To-do"` in handwritten 17pt bold blue ink with a
///    matching wavy underline (the same primitive used on inline links).
/// 2. A `VStack` of `TodoRow`s sorted high-priority-first, then alphabetical
///    by title for stability across reloads.
///
/// The patch background is `rgba(255,255,200,0.35)` — a faintly yellow tint
/// chosen to read as a Post-It silhouette against the cream paper without
/// fighting the surrounding ink. The 0.5pt dashed `theme.ink3` border carries
/// the rest of the visual weight. Both values come straight from the mock.
struct TodoBlock: View {
    /// To-dos to render for the focused day. The view sorts a local copy by
    /// priority desc then title; callers can pass any order.
    let tasks: [TaskItem]

    /// Forwarded to each row's tap action, scoped to that row's task id.
    /// The day-page view model wires this to `TaskStoring.toggle(id:)`.
    var onToggle: (UUID) -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        if tasks.isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    // MARK: - Subviews

    /// Composes header + sorted rows inside the yellow dashed patch. Split
    /// out so the outer `body` only carries the empty-state gate.
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(sortedTasks, id: \.id) { task in
                    TodoRow(task: task) { onToggle(task.id) }
                        .accessibleTask(task) { onToggle(task.id) }
                        .accessibilityIdentifier(AccessibilityIDs.daypageTodoRow(task.id))
                }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 8, trailing: 12))
        .background(RoundedRectangle(cornerRadius: 2)
            .fill(Self.patchBackground))
        .dashedBorder(color: theme.ink3, dash: [4, 3], lineWidth: 0.5, cornerRadius: 2)
    }

    /// Blue-ink "To-do" caption with a wavy underline matching the link
    /// decoration. The wave color is the same 30%-blue used elsewhere in
    /// the design system so the patch reads as part of the page, not a
    /// foreign component.
    private var header: some View {
        Text("To-do")
            .font(font.font(at: 17 * size.scale, weight: .bold))
            .foregroundStyle(theme.blueInk)
            .wavyUnderline(color: theme.blueInk.opacity(0.3), amplitude: 1, wavelength: 6)
    }

    /// Sort key: priority descending (high first), then title ascending so
    /// reorderings are deterministic across reloads. Returns a fresh array
    /// rather than mutating in place to keep `body` pure.
    private var sortedTasks: [TaskItem] {
        tasks.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority.sortWeight > rhs.priority.sortWeight
            }
            return lhs.title < rhs.title
        }
    }

    /// `rgba(255, 255, 200, 0.35)` — the Post-It yellow specified in the
    /// mock. No theme color matches, so it's spelled out here as a literal
    /// and lives as a private static to avoid recomputing on every render.
    private static let patchBackground = Color(.sRGB,
                                               red: 1.0,
                                               green: 1.0,
                                               blue: 200.0 / 255.0,
                                               opacity: 0.35)
}

// MARK: - Previews

#Preview("TodoBlock · Three tasks (cream)") {
    let calendar = WeekMath.mondayCalendar()
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 16
    let due = calendar.date(from: components) ?? Date()

    let tasks = [
        TaskItem(title: "Water plants", due: due, done: true, priority: .low, category: .personal),
        TaskItem(title: "Buy gift for Sara", due: due, priority: .high, category: .family),
        TaskItem(title: "Confirm dinner reservation",
                 due: due,
                 priority: .med,
                 category: .personal),
    ]

    return ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                TodoBlock(tasks: tasks, onToggle: { _ in })
                    .padding(.top, 40)
                    .padding(.leading, 44)
                    .padding(.trailing, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}
