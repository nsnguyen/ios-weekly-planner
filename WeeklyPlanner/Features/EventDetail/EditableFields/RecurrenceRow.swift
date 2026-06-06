import SwiftUI

/// "Repeat" editable row: frequency menu, then (when repeating) an
/// "every N <unit>s" stepper line and an end-condition line.
struct RecurrenceRow: View {
    @Binding var recurrence: Recurrence?

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("Repeat")
                    .font(font.font(at: 15 * size.scale, weight: .regular))
                    .foregroundStyle(theme.ink2)
                    .frame(width: 72, alignment: .leading)

                Menu {
                    Button("None") { recurrence = nil }
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                        Button(frequency.displayName) { setFrequency(frequency) }
                    }
                } label: {
                    Text(recurrence?.frequency.displayName ?? "None")
                        .font(font.font(at: 15 * size.scale, weight: .regular))
                        .foregroundStyle(theme.ink)
                }
                .tint(theme.blueInk)
                .accessibilityLabel("Repeat")
                .accessibilityValue(recurrence?.frequency.displayName ?? "None")
                .accessibilityIdentifier(AccessibilityIDs.eventRepeatMenu)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)

            if let current = recurrence {
                intervalLine(current)
                endLine(current)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.ink3).frame(height: 0.5)
        }
    }

    private func setFrequency(_ frequency: RecurrenceFrequency) {
        if var current = recurrence {
            current.frequency = frequency
            recurrence = current
        } else {
            recurrence = Recurrence(frequency: frequency)
        }
    }

    private func intervalLine(_ current: Recurrence) -> some View {
        HStack(spacing: 10) {
            Spacer().frame(width: 72)
            Button {
                update { $0.interval = max(1, $0.interval - 1) }
            } label: {
                Image(systemName: "minus.circle").font(.system(size: 16))
                    .foregroundStyle(current.interval > 1 ? theme.blueInk : theme.ink3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Less often")
            .accessibilityIdentifier(AccessibilityIDs.eventRepeatIntervalMinus)

            Text(current.interval == 1
                 ? "Every \(current.frequency.unitName)"
                 : "Every \(current.interval) \(current.frequency.unitName)s")
                .font(font.font(at: 14 * size.scale, weight: .regular))
                .foregroundStyle(theme.ink)

            Button {
                update { $0.interval += 1 }
            } label: {
                Image(systemName: "plus.circle").font(.system(size: 16))
                    .foregroundStyle(theme.blueInk)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More often")
            .accessibilityIdentifier(AccessibilityIDs.eventRepeatIntervalPlus)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
    }

    private func endLine(_ current: Recurrence) -> some View {
        HStack(spacing: 10) {
            Spacer().frame(width: 72)

            Menu {
                Button("Never") { update { $0.end = .never } }
                Button("On a date") {
                    update { $0.end = .onDate(defaultEndDate) }
                }
                Button("After 10 times") { update { $0.end = .afterCount(10) } }
            } label: {
                Text(endLabel(current.end))
                    .font(font.font(at: 14 * size.scale, weight: .regular))
                    .foregroundStyle(theme.ink)
            }
            .tint(theme.blueInk)
            .accessibilityLabel("Ends")
            .accessibilityValue(endLabel(current.end))
            .accessibilityIdentifier(AccessibilityIDs.eventRepeatEndMenu)

            if case let .onDate(date) = current.end {
                DatePicker("", selection: Binding(
                    get: { date },
                    set: { newDate in update { $0.end = .onDate(newDate) } }),
                    displayedComponents: [.date])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(theme.blueInk)
            }

            if case let .afterCount(count) = current.end {
                Stepper("", value: Binding(
                    get: { count },
                    set: { newCount in update { $0.end = .afterCount(max(1, newCount)) } }),
                    in: 1 ... 999)
                    .labelsHidden()
                    .accessibilityLabel("Number of times")
            }

            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
    }

    private func endLabel(_ end: RecurrenceEnd) -> String {
        switch end {
        case .never: "Never ends"
        case .onDate: "Until"
        case let .afterCount(count): "\(count) times"
        }
    }

    private var defaultEndDate: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    }

    private func update(_ transform: (inout Recurrence) -> Void) {
        guard var current = recurrence else { return }
        transform(&current)
        recurrence = current
    }
}

#Preview("RecurrenceRow · weekly, after 6") {
    @Previewable @State var recurrence: Recurrence? =
        Recurrence(frequency: .weekly, interval: 2, end: .afterCount(6))
    return RecurrenceRow(recurrence: $recurrence)
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
