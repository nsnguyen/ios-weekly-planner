import SwiftUI

/// Compact tappable to-do row used inside a `WeekDayRow`. Mirrors `TodoRow`
/// but trims down: 11×11 checkbox (vs 15×15), 14pt handwriting title in the
/// muted ink (vs 17pt in primary ink), and a `!` priority glyph for open
/// high-priority items.
///
/// The whole row is wrapped in a `.plain`-styled `Button` so the user can tap
/// anywhere along the line to toggle done. All colors and fonts come from the
/// environment — no hex literals.
struct WeekTaskEntry: View {
    /// The to-do this row represents.
    let task: TaskItem

    /// Invoked when the user taps anywhere on the row. The week-page view
    /// model wires this to `TaskStoring.toggle(id:)`.
    var onToggle: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                checkbox
                title
                if showsPriorityBang {
                    priorityBang
                }
            }
            .padding(.top, 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibleTask(task) { onToggle() }
    }

    // MARK: - Subviews

    /// 11×11 ink-bordered white square with an optional blue-ink check overlay
    /// when `task.done`. The check is the same two-segment path as `TodoRow`,
    /// scaled to fit the smaller box.
    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 1)
                        .strokeBorder(theme.ink, lineWidth: 1.3)
                }

            if task.done {
                WeekCheckmarkShape()
                    .stroke(theme.blueInk,
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 9, height: 9)
            }
        }
        .frame(width: 11, height: 11)
        .alignmentGuide(.firstTextBaseline) { dimension in
            // Anchor the box near the text baseline so the row reads as a
            // hand-drawn list item rather than a top-aligned checkbox UI.
            dimension[.bottom] - 2
        }
    }

    /// Title text: handwriting at 14pt, muted ink (ink3 when done), single
    /// line with tail ellipsis, strikethrough in `theme.redInk` when done.
    private var title: some View {
        Text(task.title)
            .font(font.font(at: 14, weight: .regular))
            .foregroundStyle(task.done ? theme.ink3 : theme.ink2)
            .lineLimit(1)
            .strikethrough(task.done, color: theme.redInk)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Trailing exclamation mark shown only for unfinished high-priority
    /// tasks. System bold so it pops against the handwriting title.
    private var priorityBang: some View {
        Text("!")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(theme.redInk)
    }

    /// Convenience predicate so the body reads top-to-bottom in spec order.
    private var showsPriorityBang: Bool {
        task.priority == .high && !task.done
    }
}

// MARK: - CheckmarkShape

/// Two-segment polyline from `(2, 7)` through `(5, 10)` to `(11, 3)` on a
/// 13×13 reference grid, scaled to fill the caller's rect. Named with the
/// `Week` prefix so a future shared shape doesn't collide with `TodoRow`'s
/// `CheckmarkShape`.
private struct WeekCheckmarkShape: Shape {
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

#Preview("WeekTaskEntry · Three states") {
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
                    WeekTaskEntry(task: undone, onToggle: {})
                    WeekTaskEntry(task: done, onToggle: {})
                    WeekTaskEntry(task: high, onToggle: {})
                }
                .padding(.top, 40)
                .padding(.leading, 60)
                .padding(.trailing, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 60)
    }
    .paperTheme(.cream)
}
