import SwiftUI

/// One row of the editable event composer: handwriting label on the
/// leading edge, compact date+time picker on the trailing. Used twice
/// per composer — once for `start`, once for `end`.
///
/// The label flips to `theme.redInk` when `invalidHint == true` so the
/// "end before start" condition is visible without a separate banner.
struct PaperDateTimeRow: View {
    let label: String
    @Binding var date: Date
    var invalidHint: Bool = false

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font
    @Environment(\.paperSize) private var size

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(font.font(at: 15 * size.scale, weight: .regular))
                .foregroundStyle(invalidHint ? theme.redInk : theme.ink2)
                .frame(width: 72, alignment: .leading)

            DatePicker("",
                       selection: $date,
                       displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(theme.blueInk)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.ink3)
                .frame(height: 0.5)
        }
    }
}
