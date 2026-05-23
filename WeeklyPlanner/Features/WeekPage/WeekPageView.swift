import SwiftUI

/// The composite Hobonichi-style week spread: paper book chrome + ruled lines
/// + red margin + hole punches + header + seven `WeekDayRow`s + bottom-right
/// `WeekStickyNote` + page-number footer for a single `weekOffset`.
///
/// Renders ONE static week page — Group T will host this inside a flip
/// container alongside `DayPageView`. Owns a `WeekPageViewModel` instance
/// per `weekOffset` and refreshes it once on `.task`; real-time observation
/// is deferred until SwiftData `@Model` values are `Sendable` across actor
/// hops (same policy as `DayPageView`).
///
/// Tokens flow in from `@Environment(\.paperTheme)`, `\.paperFont`, and
/// `\.paperSize`; the three stores are pulled from `@Environment` as well so
/// previews can inject stubs without standing up a real SwiftData container.
struct WeekPageView: View {
    /// Week relative to "today's week" (0 = current). Forwarded to the view
    /// model and used to pick the right `WeekMeta`.
    let weekOffset: Int

    @Environment(\.eventStore) private var eventStore
    @Environment(\.taskStore) private var taskStore
    @Environment(\.inboxStore) private var inboxStore
    @Environment(\.inboxSyncEngine) private var inboxSyncEngine

    /// Lazily-instantiated view model; nil until `.task` runs once on first
    /// appear, at which point we create it and call `refresh()`.
    @State private var viewModel: WeekPageViewModel?

    /// Identifier of the event whose detail sheet is currently open. `nil`
    /// when no sheet is presented. Tapping any compact `WeekEventEntry`
    /// row sets this.
    @State private var openEventID: UUID?

    var body: some View {
        let now = Date()
        let days = WeekMath.weekDays(forOffset: weekOffset, today: now)
        let weekMeta = WeekMath.weekMeta(forOffset: weekOffset, today: now)
        let year = days.first?.year ?? 0
        let todayIdx = weekOffset == 0 ? WeekMath.todayIndex(in: days, for: now) : nil

        return ZStack {
            BookPage {
                PaperSurface {
                    ZStack(alignment: .topLeading) {
                        PaperGrain()
                        RuledLines()
                        RedMarginLine()
                        HolePunches()

                        ScrollView {
                            content(days: days, weekMeta: weekMeta, year: year, todayIdx: todayIdx)
                                .padding(EdgeInsets(top: 2, leading: 44, bottom: 14, trailing: 18))
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .refreshable {
                            await viewModel?.refresh(via: inboxSyncEngine)
                        }

                        stickyNoteOverlay
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(.trailing, 14)
                            .padding(.bottom, 14)

                        PageNumber(date: days.first?.date ?? .init())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }
            }

            if let id = openEventID {
                PaperEventSheet(initialMode: .view(id),
                                isOpen: Binding(get: { openEventID != nil },
                                                set: { if !$0 { openEventID = nil } }))
            }
        }
        .task {
            if viewModel == nil {
                viewModel = WeekPageViewModel(weekOffset: weekOffset,
                                              eventStore: eventStore,
                                              taskStore: taskStore,
                                              inboxStore: inboxStore)
            }
            await viewModel?.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventStoreDidChange)) { _ in
            Task { await viewModel?.refresh() }
        }
    }

    // MARK: - Subviews

    /// Header + seven rows. Split out so `body` stays readable and the leading
    /// 44pt inset (which clears the red margin) is applied once on the whole
    /// content column.
    private func content(days: [WeekDay], weekMeta: WeekMeta, year: Int, todayIdx: Int?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            WeekPageHeader(weekMeta: weekMeta,
                           year: year,
                           eventCount: viewModel?.eventCount ?? 0,
                           openTaskCount: viewModel?.openTaskCount ?? 0)

            if viewModel != nil {
                VStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.element.idx) { offset, day in
                        WeekDayRow(day: day,
                                   events: viewModel?.eventsByDay[day.idx] ?? [],
                                   tasks: viewModel?.tasksByDay[day.idx] ?? [],
                                   isToday: todayIdx == day.idx,
                                   showSeparator: offset < days.count - 1,
                                   onToggleTask: { id in
                                       Task { await viewModel?.toggleTask(id: id) }
                                   },
                                   onTapEvent: { id in
                                       openEventID = id
                                   })
                            .accessibleWeekDayRow(weekdayFull: day.weekdayLong, dayN: offset + 1)
                            .accessibilityIdentifier(AccessibilityIDs.weekpageDayRow(day.idx))
                    }
                }
                .accessibilityRotor("Days") {
                    ForEach(Array(days.enumerated()), id: \.element.idx) { offset, day in
                        AccessibilityRotorEntry(
                            AccessibilityFormatters.sideTabLabel(weekdayFull: day.weekdayLong, dayN: offset + 1),
                            id: day.idx
                        )
                    }
                }
            }
        }
    }

    /// Bottom-right sticky note overlay. Wrapped in a `ViewBuilder` so the
    /// view-model-less first render doesn't trip the `inboxCount` parameter.
    private var stickyNoteOverlay: some View {
        WeekStickyNote(weekOffset: weekOffset, inboxCount: viewModel?.inboxCount ?? 0)
    }
}

// MARK: - Previews

#Preview("WeekPageView · Today (stub stores)") {
    ZStack {
        BookCover()
        WeekPageView(weekOffset: 0)
            .padding(.top, Spacing.bookTopBarTopPadding)
            .padding(.bottom, Spacing.tabBarHeight + Spacing.tabBarBottomSafeArea)
    }
    .environment(\.eventStore, StubEventStore())
    .environment(\.taskStore, StubTaskStore())
    .environment(\.inboxStore, StubInboxStore())
    .paperTheme(.cream)
}

#Preview("WeekPageView · Next week (stub stores)") {
    ZStack {
        BookCover()
        WeekPageView(weekOffset: 1)
            .padding(.top, Spacing.bookTopBarTopPadding)
            .padding(.bottom, Spacing.tabBarHeight + Spacing.tabBarBottomSafeArea)
    }
    .environment(\.eventStore, StubEventStore())
    .environment(\.taskStore, StubTaskStore())
    .environment(\.inboxStore, StubInboxStore())
    .paperTheme(.cream)
}
