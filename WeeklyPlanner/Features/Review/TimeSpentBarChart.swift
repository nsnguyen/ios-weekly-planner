import SwiftUI

/// "Time spent" section: wavy-underlined header + one CategoryTimeRow per
/// category, sorted by hours descending. Categories with 0 hours are
/// omitted so the chart never renders empty bars; when *all* categories
/// have 0 hours (a fresh install or a week with only inbox suggestions),
/// a placeholder line keeps the section from reading as broken.
struct TimeSpentBarChart: View {
    let timeByCategory: [Category: Double]
    let maxHours: Double

    @Environment(\.paperTheme) private var theme
    @Environment(\.paperFont) private var font

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Time spent")
                .font(font.font(at: 20, weight: .bold))
                .foregroundStyle(theme.ink)
                .modifier(WavyUnderline(color: theme.ink.opacity(0.25),
                                         amplitude: 1,
                                         wavelength: 6))
                .padding(.bottom, 8)

            let visibleRows = Self.rows(from: timeByCategory)
            if visibleRows.isEmpty {
                Text(Self.emptyStateCopy)
                    .font(.custom("Cochin-Italic", size: 13))
                    .foregroundStyle(theme.ink2)
                    .padding(.vertical, 4)
            } else {
                ForEach(visibleRows, id: \.0) { entry in
                    CategoryTimeRow(category: entry.0,
                                     hours: entry.1,
                                     maxHours: maxHours)
                }
            }
        }
        .padding(.top, 18)
    }

    /// Pure, testable row reducer. Drops categories with 0 hours, sorts the
    /// rest by hours descending. Exposed so the view layer and the test
    /// suite share the exact same data path.
    static func rows(from timeByCategory: [Category: Double]) -> [(Category, Double)] {
        timeByCategory
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
    }

    /// Placeholder copy shown under the section header when there are no
    /// time-spent rows for the week.
    static let emptyStateCopy = "Nothing tracked yet this week."
}
