import SwiftUI

/// "Time spent" section: wavy-underlined header + one CategoryTimeRow
/// per category, sorted by hours descending. Categories with 0 hours are
/// omitted to keep the chart from rendering empty rows.
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

            ForEach(rows, id: \.0) { entry in
                CategoryTimeRow(category: entry.0,
                                 hours: entry.1,
                                 maxHours: maxHours)
            }
        }
        .padding(.top, 18)
    }

    /// Tuple list of `(Category, hours)` sorted by hours desc, filtered to
    /// > 0. `ForEach` keys on the Category raw value.
    private var rows: [(Category, Double)] {
        timeByCategory
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
    }
}
