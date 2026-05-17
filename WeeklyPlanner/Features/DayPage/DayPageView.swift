import SwiftUI

/// The composite Day Page view: paper book chrome + ruled lines + red margin
/// + hole punches + header + events list + inbox block + page-number footer.
///
/// Assembles every Phase 05 paper primitive and every Phase 06 Day-page
/// sub-component into the full hobonichi-style page the user sees when the
/// app opens. Owns a `DayPageViewModel` instance for `(weekOffset, dayIdx)`
/// and refreshes it once on `.task`; real-time observation is deferred to a
/// later phase when SwiftData `@Model` values are Sendable across actors.
///
/// Tokens flow in from `@Environment(\.paperTheme)`, `\.paperFont`, and
/// `\.paperSize`; the two stores are pulled from `@Environment` as well so
/// previews can inject `StubEventStore` / `StubInboxStore` without standing
/// up a real SwiftData container.
struct DayPageView: View {
    /// Week relative to today's week (0 = current). Forwarded to the view model.
    let weekOffset: Int

    /// Monday-based index within the week (0 = Mon … 6 = Sun). Forwarded to
    /// the view model and used to pick the right `WeekDay` for the header.
    let dayIdx: Int

    @Environment(\.eventStore) private var eventStore
    @Environment(\.inboxStore) private var inboxStore

    /// Lazily-instantiated view model; nil until `.task` runs once on first
    /// appear, at which point we create it and call `refresh()`.
    @State private var viewModel: DayPageViewModel?

    var body: some View {
        let now = Date()
        let days = WeekMath.weekDays(forOffset: weekOffset, today: now)
        let weekDay = days.indices.contains(dayIdx) ? days[dayIdx] : days[0]
        let weekMeta = WeekMath.weekMeta(forOffset: weekOffset, today: now)

        return BookPage {
            PaperSurface {
                ZStack(alignment: .topLeading) {
                    PaperGrain()
                    RuledLines()
                    RedMarginLine()
                    HolePunches()

                    content(weekDay: weekDay, weekMeta: weekMeta)
                        .padding(.top, 18)
                        .padding(.leading, 44)
                        .padding(.trailing, 18)
                        .padding(.bottom, 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    PageNumber(date: weekDay.date)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = DayPageViewModel(weekOffset: weekOffset,
                                             dayIdx: dayIdx,
                                             eventStore: eventStore,
                                             inboxStore: inboxStore)
            }
            await viewModel?.refresh()
        }
    }

    // MARK: - Subviews

    /// Content column: header, optional events list, optional inbox block, or
    /// the empty-state hint when both are empty. Split out so `body` stays
    /// readable.
    private func content(weekDay: WeekDay, weekMeta: WeekMeta) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DayPageHeader(weekDay: weekDay,
                          weekMeta: weekMeta,
                          isToday: viewModel?.isToday ?? false)

            Spacer().frame(height: 8)

            if let viewModel {
                let hasEvents = !viewModel.events.isEmpty
                let hasInbox = !viewModel.inbox.isEmpty

                if hasEvents {
                    EventEntryList(events: viewModel.events, onTap: { _ in })
                }

                if hasInbox {
                    InboxBlock(suggestions: viewModel.inbox,
                               onAccept: { id in
                                   Task { await viewModel.accept(suggestionID: id) }
                               },
                               onDismiss: { id in
                                   Task { await viewModel.dismiss(suggestionID: id) }
                               })
                }

                if !hasEvents, !hasInbox {
                    EmptyDayState()
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("DayPageView · Today (stub stores)") {
    ZStack {
        BookCover()
        DayPageView(weekOffset: 0, dayIdx: 5)
            .padding(.top, Spacing.bookTopBarTopPadding)
            .padding(.bottom, Spacing.tabBarHeight + Spacing.tabBarBottomSafeArea)
    }
    .environment(\.eventStore, StubEventStore())
    .environment(\.inboxStore, StubInboxStore())
    .paperTheme(.cream)
}
