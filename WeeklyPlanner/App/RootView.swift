import SwiftUI

/// The root scene the user lands on when the app launches. Owns the top-level
/// navigation state — `PageFlipController` (which week / day is on screen),
/// the Day-vs-Week `paperView` toggle, and the `isPickerOpen` flag the week
/// picker (Group R) will read.
///
/// Lays out a single `BookContainer` for the leather chrome and supplies a
/// `DayPageView` as its content. Wires the container's nav callbacks back to
/// the controller:
///
/// - Top-bar week chevrons: instant `setWeek` in Day view, 3D `flipWeek` in
///   Week view (matches the Phase 09 spec's "chevron behavior split").
/// - Top-bar Today pill: hops `setWeek(0)` then animates to today's weekday
///   via `flipToDay(idx:)`.
/// - Bottom-controls day chevrons: animated `flipDay(direction:)`.
///
/// Week picker, AI overlay, and the Day/Week toggle's render switch are wired
/// in later groups (R, T, and Phase 12 respectively); the corresponding
/// callbacks here are stubs that flip local state only.
struct RootView: View {
    /// Source-of-truth for which page is on screen. Owned by `RootView` (not
    /// `DayPageView`) so the top bar and the page-flip surface share one
    /// controller and the user keeps their position when the Day/Week toggle
    /// is wired in Group T.
    @State private var controller: PageFlipController

    /// Day-vs-Week spread selector. Drives the Day/Week toggle and the
    /// top-bar / bottom-controls week-vs-day routing.
    @State private var paperView: PaperView = .day

    /// True while the week picker overlay is open. Currently toggled by the
    /// `DateRangePill` tap; Group R replaces the no-op overlay with the real
    /// picker sheet.
    @State private var isPickerOpen: Bool = false

    init() {
        let today = Date()
        let days = WeekMath.weekDays(forOffset: 0, today: today)
        let todayIdx = WeekMath.todayIndex(in: days, for: today) ?? 0
        _controller = State(initialValue: PageFlipController(current: PageCoordinate(week: 0,
                                                                                     day: todayIdx)))
    }

    var body: some View {
        let today = Date()
        let currentWeek = controller.current.week
        let weekMeta = WeekMath.weekMeta(forOffset: currentWeek, today: today)
        let isCurrentWeek = currentWeek == 0
        let currentWeekDays = WeekMath.weekDays(forOffset: 0, today: today)
        let todayIdx = WeekMath.todayIndex(in: currentWeekDays, for: today)
        let isOnTodayPage = isCurrentWeek && controller.current.day == todayIdx

        return ZStack {
            BookContainer(paperView: $paperView,
                          weekMeta: weekMeta,
                          isOnTodayPage: isOnTodayPage,
                          isPickerOpen: isPickerOpen,
                          onOpenAI: {
                              // Phase 12 will wire the AI overlay.
                          },
                          onOpenPicker: {
                              isPickerOpen.toggle()
                          },
                          onJumpToday: {
                              if let idx = todayIdx {
                                  controller.setWeek(0)
                                  controller.flipToDay(idx: idx)
                              }
                          },
                          onPrevWeek: {
                              if paperView == .day {
                                  controller.setWeek(controller.current.week - 1)
                              } else {
                                  controller.flipWeek(direction: .prev)
                              }
                          },
                          onNextWeek: {
                              if paperView == .day {
                                  controller.setWeek(controller.current.week + 1)
                              } else {
                                  controller.flipWeek(direction: .next)
                              }
                          },
                          onPrevDay: { controller.flipDay(direction: .prev) },
                          onNextDay: { controller.flipDay(direction: .next) },
                          content: {
                              // For now, always show DayPage. Group T wires
                              // the Day/Week toggle to actually switch in a
                              // Week page here.
                              DayPageView(controller: controller)
                          })

            WeekPickerSheet(isOpen: $isPickerOpen,
                            initialWeekOffset: controller.current.week)
            { offset in
                controller.setWeek(offset)
                isPickerOpen = false
            }
        }
    }
}

#Preview {
    RootView()
        .environment(\.eventStore, StubEventStore())
        .environment(\.inboxStore, StubInboxStore())
        .environment(\.taskStore, StubTaskStore())
}
