import SwiftUI

/// The flip-aware Day page entry point. Hosts a `PageFlipController`, draws
/// the side-tab column on the trailing edge, attaches the horizontal-swipe
/// gesture, and delegates the actual paper rendering to `DayPageContent` via
/// `PageFlipContainer`.
///
/// `DayPageView` is what `RootView` mounts. It owns the controller as
/// `@State` so the same instance survives view reloads while the user
/// navigates between days. Side-tab taps and swipe gestures both flow through
/// the controller, which means the rest of the app gets a single source of
/// truth for "which day is the user on right now".
///
/// Layout:
/// - `PageFlipContainer` fills the available space; inside it, each rendered
///   `DayPageContent` brings its own book chrome.
/// - `SideTabs` is overlaid on the trailing edge with a slight negative
///   trailing padding so the rounded tabs poke past the edge of the page.
struct DayPageView: View {
    @Environment(\.paperTheme) private var theme

    /// Source-of-truth for "which day is on screen". Re-initialized only when
    /// the parent supplies a new `initialCoordinate`; subsequent flips mutate
    /// the controller in-place.
    @State private var controller: PageFlipController

    /// Construct a `DayPageView` anchored on the given starting coordinate.
    /// Typically `(week: 0, day: todayIdx)` so the user lands on today.
    init(initialCoordinate: PageCoordinate) {
        _controller = State(initialValue: PageFlipController(current: initialCoordinate))
    }

    var body: some View {
        let now = Date()
        let weekDays = WeekMath.weekDays(forOffset: controller.current.week, today: now)
        let currentWeekDays = WeekMath.weekDays(forOffset: 0, today: now)
        let todayIdx = WeekMath.todayIndex(in: currentWeekDays, for: now)
        let isCurrentWeek = controller.current.week == 0

        return HStack(alignment: .top, spacing: 4) {
            SideTabs(weekDays: weekDays,
                     selectedIdx: controller.current.day,
                     todayIdx: isCurrentWeek ? todayIdx : nil,
                     onSelect: { idx in controller.flipToDay(idx: idx) })

            PageFlipContainer(controller: controller) { coord in
                DayPageContent(weekOffset: coord.week, dayIdx: coord.day)
            }
            .horizontalSwipe { direction in
                controller.flipDay(direction: direction)
            }
        }
    }
}

/// The composite Day Page view: paper book chrome + ruled lines + red margin
/// + hole punches + header + events list + inbox block + to-do patch +
/// page-number footer for a single `(weekOffset, dayIdx)` cell.
///
/// Renders ONE static day page — `DayPageView` wraps several of these in
/// `PageFlipContainer` to animate between days. Owns a `DayPageViewModel`
/// instance for `(weekOffset, dayIdx)` and refreshes it once on `.task`;
/// real-time observation is deferred to a later phase when SwiftData `@Model`
/// values are Sendable across actors.
///
/// Tokens flow in from `@Environment(\.paperTheme)`, `\.paperFont`, and
/// `\.paperSize`; the three stores are pulled from `@Environment` as well so
/// previews can inject `StubEventStore` / `StubInboxStore` / `StubTaskStore`
/// without standing up a real SwiftData container.
struct DayPageContent: View {
    /// Week relative to today's week (0 = current). Forwarded to the view model.
    let weekOffset: Int

    /// Monday-based index within the week (0 = Mon … 6 = Sun). Forwarded to
    /// the view model and used to pick the right `WeekDay` for the header.
    let dayIdx: Int

    @Environment(\.eventStore) private var eventStore
    @Environment(\.inboxStore) private var inboxStore
    @Environment(\.taskStore) private var taskStore
    @Environment(\.modelContext) private var modelContext

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
                        .overlay(alignment: .topTrailing) {
                            stickyNoteOverlay
                        }

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
                                             inboxStore: inboxStore,
                                             taskStore: taskStore)
            }
            await viewModel?.refresh()
        }
    }

    // MARK: - Subviews

    /// Top-right AI sticky note, gated on the presence of a non-dismissed
    /// `AIInsight` row for this `(weekOffset, dayIdx)` cell. Padded 16pt off
    /// the page's top/trailing edges so the masking-tape overhang stays
    /// inside the paper. If no insight exists the overlay collapses to an
    /// `EmptyView` and the corner is left blank — the design treats absent
    /// stickies as "no note today", not "blank placeholder".
    @ViewBuilder
    private var stickyNoteOverlay: some View {
        if let insight = StickyNoteGenerator.insight(forWeekOffset: weekOffset,
                                                     dayIdx: dayIdx,
                                                     in: modelContext)
        {
            AIStickyNote(insight: insight)
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
    }

    /// Content column: header, optional events list, optional inbox block,
    /// optional to-do patch, or the empty-state hint when all three are
    /// empty. Split out so `body` stays readable.
    private func content(weekDay: WeekDay, weekMeta: WeekMeta) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DayPageHeader(weekDay: weekDay,
                          weekMeta: weekMeta,
                          isToday: viewModel?.isToday ?? false)

            Spacer().frame(height: 8)

            if let viewModel {
                let hasEvents = !viewModel.events.isEmpty
                let hasInbox = !viewModel.inbox.isEmpty
                let hasTasks = !viewModel.tasks.isEmpty

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

                if hasTasks {
                    TodoBlock(tasks: viewModel.tasks) { id in
                        Task { await viewModel.toggleTask(id: id) }
                    }
                    .padding(.top, 12)
                }

                if !hasEvents, !hasInbox, !hasTasks {
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
        DayPageView(initialCoordinate: PageCoordinate(week: 0, day: 5))
            .padding(.top, Spacing.bookTopBarTopPadding)
            .padding(.bottom, Spacing.tabBarHeight + Spacing.tabBarBottomSafeArea)
    }
    .environment(\.eventStore, StubEventStore())
    .environment(\.inboxStore, StubInboxStore())
    .environment(\.taskStore, StubTaskStore())
    .paperTheme(.cream)
}

#Preview("DayPageContent · Today (stub stores)") {
    ZStack {
        BookCover()
        DayPageContent(weekOffset: 0, dayIdx: 5)
            .padding(.top, Spacing.bookTopBarTopPadding)
            .padding(.bottom, Spacing.tabBarHeight + Spacing.tabBarBottomSafeArea)
    }
    .environment(\.eventStore, StubEventStore())
    .environment(\.inboxStore, StubInboxStore())
    .environment(\.taskStore, StubTaskStore())
    .paperTheme(.cream)
}
