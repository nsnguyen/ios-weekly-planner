import SwiftUI

/// A single hand-drawn to-do row inside `TodoBlock`: a 15×15 ink checkbox, the
/// task title in the active handwriting family, and — for unfinished
/// high-priority items — a trailing red `"!"` glyph. The whole row is a single
/// `Button` so the user can tap anywhere along the line to toggle done.
///
/// When `task.done` flips, the checkmark fades and scales in with a 0.15s
/// ease-out animation. Strikethrough on the title is the standard SwiftUI
/// `.strikethrough(_:color:)` so it follows the redInk pen color from the
/// active `PaperTheme`.
///
/// Accessibility: the row publishes a combined label
/// (`"<title>, completed|not completed"`), advertises the `.isButton` trait,
/// and inflates the hit target by 8pt on every side so VoiceOver / Switch
/// Control users land it reliably even though the checkbox itself is small.
struct TodoRow: View {
    /// The to-do this row represents. The view reads `title`, `done`, and
    /// `priority` directly off the model.
    let task: TaskItem

    /// Invoked when the user taps anywhere on the row (including the
    /// checkbox). The day-page view model wires this to
    /// `TaskStoring.toggle(id:)`.
    var onToggle: () -> Void

    /// Optional. Invoked when the user picks "Delete" from the trailing swipe
    /// action or the long-press context menu. `nil` hides both affordances.
    var onDelete: (() -> Void)?

    /// Optional. Invoked when the user picks "Edit" from the long-press
    /// context menu. `nil` hides the Edit item.
    var onLongPress: (() -> Void)?

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    init(task: TaskItem,
         onToggle: @escaping () -> Void,
         onDelete: (() -> Void)? = nil,
         onLongPress: (() -> Void)? = nil)
    {
        self.task = task
        self.onToggle = onToggle
        self.onDelete = onDelete
        self.onLongPress = onLongPress
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                checkbox
                title
                if showsPriorityBang {
                    priorityBang
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle().inset(by: -4))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            if let onLongPress {
                Button {
                    onLongPress()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Subviews

    /// 15×15 white square with a 1.4pt ink border and an optional blue-ink
    /// checkmark overlay. The check is drawn via a `Path` traced against a
    /// 13×13 reference grid, then scaled to fit the inner 13×13 area of the
    /// box — keeping the geometry independent of the surrounding font scale.
    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 1)
                        .strokeBorder(theme.ink, lineWidth: 1.4)
                }

            if task.done {
                checkPath
                    .stroke(theme.blueInk,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 13, height: 13)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 15, height: 15)
        .animation(.easeOut(duration: 0.15), value: task.done)
        .alignmentGuide(.firstTextBaseline) { dimension in
            // Anchor the box near the text baseline so the row reads as a
            // hand-drawn list item rather than a top-aligned checkbox UI.
            dimension[.bottom] - 2
        }
    }

    /// The check stroke itself: `M2,7 → L5,10 → L11,3` traced through the
    /// 13×13 viewbox. Returning a `Shape` (rather than rendering inside a
    /// `Canvas`) keeps the path participate in SwiftUI's transition system
    /// so the scale + opacity animation reads cleanly.
    private var checkPath: some Shape {
        CheckmarkShape()
    }

    /// Title text: handwriting at 17pt × user size step, muted when done,
    /// strikethrough in `theme.redInk` when done.
    private var title: some View {
        Text(task.title)
            .font(font.font(at: 17 * size.scale, weight: .medium))
            .foregroundStyle(task.done ? theme.ink2 : theme.ink)
            .strikethrough(task.done, color: theme.redInk)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Trailing exclamation mark shown only for unfinished high-priority
    /// tasks. Sized in system bold so it pops against the handwriting title.
    private var priorityBang: some View {
        Text("!")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(theme.redInk)
    }

    /// Convenience predicate so the body reads top-to-bottom in spec order.
    private var showsPriorityBang: Bool {
        task.priority == .high && !task.done
    }
}

// MARK: - CheckmarkShape

/// Two-segment polyline from `(2, 7)` through `(5, 10)` to `(11, 3)`,
/// laid out on a 13×13 reference grid then proportionally scaled to fill
/// whatever container the caller hands it.
private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 13
        let scaleY = rect.height / 13
        var path = Path()
        path.move(to: CGPoint(x: 2 * scaleX, y: 7 * scaleY))
        path.addLine(to: CGPoint(x: 5 * scaleX, y: 10 * scaleY))
        path.addLine(to: CGPoint(x: 11 * scaleX, y: 3 * scaleY))
        return path
    }
}

// MARK: - Previews

#Preview("TodoRow · Three states (cream)") {
    let calendar = WeekMath.mondayCalendar()
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 16
    let due = calendar.date(from: components) ?? Date()

    let undone = TaskItem(title: "Water plants", due: due, priority: .low, category: .personal)
    let done = TaskItem(title: "Confirm dinner reservation",
                        due: due,
                        done: true,
                        priority: .low,
                        category: .personal)
    let high = TaskItem(title: "Buy gift for Sara", due: due, priority: .high, category: .family)

    return ZStack {
        BookCover()
        BookPage {
            PaperSurface {
                VStack(alignment: .leading, spacing: 0) {
                    TodoRow(task: undone, onToggle: {})
                    TodoRow(task: done, onToggle: {})
                    TodoRow(task: high, onToggle: {})
                }
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
