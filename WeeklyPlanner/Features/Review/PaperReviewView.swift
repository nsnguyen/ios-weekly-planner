import SwiftUI
import SwiftData

/// Root of the Review page. Wraps the existing paper chrome (BookPage +
/// PaperSurface + RuledLines + RedMarginLine + HolePunches) around a
/// vertical scroll column that hosts the five Review sections.
///
/// The view-model is built inside `.task` so we can read the Intelligence
/// service from `@Environment(\.intelligenceService)` and inject a real
/// `WeekSummaryGenerator` when available.
struct PaperReviewView: View {
    /// Week relative to today's week. Phase 14 always passes 0; future
    /// weekly navigation is out of scope per spec.
    let weekOffset: Int

    @Environment(\.eventStore) private var eventStore
    @Environment(\.taskStore) private var taskStore
    @Environment(\.intelligenceService) private var intelligenceService
    @Environment(\.paperTheme) private var theme

    @State private var viewModel: ReviewViewModel?

    var body: some View {
        BookPage {
            PaperSurface {
                ZStack(alignment: .topLeading) {
                    PaperGrain()
                    RuledLines()
                    RedMarginLine()
                    HolePunches()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if let viewModel {
                                ReviewHeader(weekOffset: viewModel.weekOffset,
                                              dateRange: Self.formatWeekRange(weekOffset: viewModel.weekOffset,
                                                                              today: Date()),
                                              completionPercent: viewModel.completionPercent)
                                ReviewSummaryBlock(summaryBody: viewModel.summary.headline)
                                TimeSpentBarChart(timeByCategory: viewModel.timeByCategory,
                                                  maxHours: viewModel.maxHours)
                                AINotesList(bullets: viewModel.summary.bullets)
                                StreaksBlock(streaks: viewModel.streaks)
                            } else {
                                ProgressView()
                                    .padding(.top, 60)
                            }
                        }
                        .padding(EdgeInsets(top: 14, leading: 44, bottom: 14, trailing: 14))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
        .task(id: weekOffset) {
            if viewModel == nil || viewModel?.weekOffset != weekOffset {
                let generator = intelligenceService.map { service in
                    WeekSummaryGenerator(intelligence: service,
                                          events: eventStore,
                                          tasks: taskStore)
                }
                viewModel = ReviewViewModel(weekOffset: weekOffset,
                                             eventStore: eventStore,
                                             taskStore: taskStore,
                                             summaryGenerator: generator)
            }
            await viewModel?.refresh()
        }
    }

    /// Formatter shared by the header. POSIX-locked so unit tests stay
    /// deterministic.
    private static func formatWeekRange(weekOffset: Int, today: Date) -> String {
        let calendar = WeekMath.mondayCalendar()
        let monday = WeekMath.weekDays(forOffset: weekOffset, today: today).first?.date ?? today
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
        let day = DateFormatter()
        day.dateFormat = "d"
        day.locale = Locale(identifier: "en_US_POSIX")
        let monthYear = DateFormatter()
        monthYear.dateFormat = "MMM yyyy"
        monthYear.locale = Locale(identifier: "en_US_POSIX")
        return "\(day.string(from: monday)) – \(day.string(from: sunday)) \(monthYear.string(from: monday))"
    }
}

#Preview("PaperReviewView · cream") {
    PaperReviewView(weekOffset: 0)
        .paperTheme(.cream)
        .environment(\.eventStore, StubEventStore())
        .environment(\.taskStore, StubTaskStore())
        .environment(\.inboxStore, StubInboxStore())
}
