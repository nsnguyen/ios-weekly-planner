import SwiftUI

/// One row in the Time spent chart: label on the left, dotted-baseline
/// bar in the middle filled to the category's hour proportion, and a
/// right-aligned hours value.
struct CategoryTimeRow: View {
    let category: Category
    let hours: Double
    let maxHours: Double

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(category.reviewDisplayName)
                .font(font.font(at: 16, weight: .regular))
                .foregroundStyle(theme.ink)
                .frame(width: 64, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: proxy.size.height))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                    }
                    .stroke(theme.ink3, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))

                    RoundedRectangle(cornerRadius: 1)
                        .fill(category.reviewBarColor.opacity(0.55))
                        .frame(width: max(0, min(proxy.size.width,
                                                  proxy.size.width * CGFloat(hours / max(maxHours, 0.0001)))))
                        .padding(.top, 1)
                        .padding(.bottom, 1)
                }
            }
            .frame(height: 14)

            Text(String(format: "%.1fh", hours))
                .font(.custom("Cochin", size: 12))
                .monospacedDigit()
                .foregroundStyle(theme.ink2)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

private extension Category {
    /// Display label for the row's leading text.
    var reviewDisplayName: String {
        switch self {
        case .work: return "Work"
        case .personal: return "Personal"
        case .health: return "Health"
        case .family: return "Family"
        case .focus: return "Focus"
        case .travel: return "Travel"
        }
    }

    /// Ink/dot color for the chart fill. Matches the existing category
    /// palette already used elsewhere — re-derived here to keep the
    /// Review feature free of cross-feature reaches.
    var reviewBarColor: Color {
        switch self {
        case .work: return Color(red: 0.36, green: 0.51, blue: 0.84)
        case .personal: return Color(red: 0.80, green: 0.45, blue: 0.20)
        case .health: return Color(red: 0.28, green: 0.59, blue: 0.36)
        case .family: return Color(red: 0.75, green: 0.40, blue: 0.55)
        case .focus: return Color(red: 0.55, green: 0.40, blue: 0.80)
        case .travel: return Color(red: 0.30, green: 0.65, blue: 0.65)
        }
    }
}
