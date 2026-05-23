import SwiftUI

/// Floating paper-card popover anchored to a `TodoRow` via SwiftUI's
/// `.popover()` modifier. Lets the user adjust priority (3 ink swatches),
/// due date (Today / Tomorrow / Pick…), or delete the task.
///
/// The popover commits each control change immediately — no Save
/// button. Tapping "Done" dismisses; tapping "Delete" raises a
/// confirmation via the caller's `onDelete` callback.
struct TaskMiniPopover: View {
    let task: TaskItem
    let onPriorityChange: (Priority) -> Void
    let onDueChange: (Date) -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    @State private var pickingDate: Date

    init(task: TaskItem,
         onPriorityChange: @escaping (Priority) -> Void,
         onDueChange: @escaping (Date) -> Void,
         onDelete: @escaping () -> Void,
         onDismiss: @escaping () -> Void)
    {
        self.task = task
        self.onPriorityChange = onPriorityChange
        self.onDueChange = onDueChange
        self.onDelete = onDelete
        self.onDismiss = onDismiss
        _pickingDate = State(initialValue: task.due)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            priorityRow
            dueRow
            Divider().background(theme.ink3)
            deleteRow
            HStack {
                Spacer()
                Button("Done", action: onDismiss)
                    .font(font.font(at: 15 * size.scale, weight: .bold))
                    .foregroundStyle(theme.blueInk)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("daypage.todo.popover.done")
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .frame(minWidth: 240)
        .presentationCompactAdaptation(.popover)
    }

    // MARK: - Subviews

    private var header: some View {
        Text("Edit task")
            .font(font.font(at: 13 * size.scale, weight: .regular))
            .foregroundStyle(theme.ink2)
    }

    private var priorityRow: some View {
        HStack(spacing: 12) {
            Text("Priority")
                .font(font.font(at: 15 * size.scale, weight: .regular))
                .foregroundStyle(theme.ink2)
                .frame(width: 72, alignment: .leading)

            HStack(spacing: 14) {
                ForEach(Priority.allCases, id: \.self) { priority in
                    swatch(for: priority)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func swatch(for priority: Priority) -> some View {
        let isSelected = task.priority == priority
        let color: Color = switch priority {
        case .low: theme.ink3
        case .med: Color(.sRGB, red: 0.95, green: 0.78, blue: 0.30, opacity: 1)
        case .high: theme.redInk
        }
        return Button {
            onPriorityChange(priority)
        } label: {
            ZStack {
                Circle().fill(color).frame(width: 18, height: 18)
                if isSelected {
                    Circle()
                        .stroke(theme.ink, lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                }
            }
            .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(priority.rawValue.capitalized) priority")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var dueRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Due")
                    .font(font.font(at: 15 * size.scale, weight: .regular))
                    .foregroundStyle(theme.ink2)
                    .frame(width: 72, alignment: .leading)

                dueChip(label: "Today", date: startOfDay(Date()))
                dueChip(label: "Tomorrow", date: startOfDay(Date().addingTimeInterval(86_400)))
                dueChip(label: "Pick…", date: nil)
                Spacer(minLength: 0)
            }

            if showsDatePicker {
                DatePicker("",
                           selection: $pickingDate,
                           displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(theme.blueInk)
                    .onChange(of: pickingDate) { _, newValue in
                        onDueChange(newValue)
                    }
            }
        }
    }

    @State private var showsDatePicker: Bool = false

    private func dueChip(label: String, date: Date?) -> some View {
        let isCurrent: Bool = {
            guard let date else { return showsDatePicker }
            return isSameDay(task.due, date)
        }()
        return Button {
            if let date {
                showsDatePicker = false
                onDueChange(date)
            } else {
                showsDatePicker.toggle()
            }
        } label: {
            Text(label)
                .font(font.font(at: 14 * size.scale,
                                weight: isCurrent ? .bold : .regular))
                .foregroundStyle(isCurrent ? theme.blueInk : theme.ink2)
                .underline(isCurrent, color: theme.blueInk)
        }
        .buttonStyle(.plain)
    }

    private var deleteRow: some View {
        Button(action: onDelete) {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                Text("Delete task")
                    .font(font.font(at: 15 * size.scale, weight: .regular))
            }
            .foregroundStyle(theme.redInk)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("daypage.todo.popover.delete")
    }

    // MARK: - Helpers

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }
}
