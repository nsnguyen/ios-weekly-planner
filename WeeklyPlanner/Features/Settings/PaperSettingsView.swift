import SwiftUI

/// The embedded Settings page. Sits inside the leather book chrome that
/// `AppShell` paints, painting its own `BookPage` + `PaperSurface` so the
/// background gradient + ruled lines + hole punches read as a real paper
/// page. Body is a `ScrollView` of five sections plus header + footer.
///
/// `SettingsViewModel` is built lazily in `.task` so a fresh navigation
/// always reads the latest `UserSettings` row.
struct PaperSettingsView: View {
    /// Phase 32 (#49): user-facing name of the on-device AI toggle. The
    /// stored setting keeps its `appleIntelligenceEnabled` code symbol.
    /// Exposed for tests.
    static let askThePlannerToggleLabel = String(localized: "Ask the planner")

    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.paperTheme) private var theme

    @State private var viewModel: SettingsViewModel?

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
                            SettingsHeader()

                            if let viewModel {
                                sections(for: viewModel)
                            } else {
                                ProgressView().padding(.top, 60)
                            }
                        }
                        .padding(.leading, 32) // clear the red margin
                        .padding(.bottom, 92)  // PaperTabBar clearance
                    }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = SettingsViewModel(store: settingsStore)
            }
        }
    }

    @ViewBuilder
    private func sections(for viewModel: SettingsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. THEME
            SectionTitle("Theme", eyebrow: "Look & feel")
            ThemeCardsGrid(selection: viewModel.themeKey) { viewModel.setTheme($0) }

            // 2. HANDWRITING
            SectionTitle("Handwriting")
            FontCardsGrid(selection: viewModel.fontKey) { viewModel.setFont($0) }

            // 3. TEXT SIZE
            SectionTitle("Text size")
            SizeSegmented(selection: Binding(
                get: { viewModel.sizeKey },
                set: { viewModel.setSize($0) }
            ))

            // 4. CONNECTIONS (Phase 17 replaces this placeholder)
            SectionTitle("Connections", eyebrow: "Sources")
            ConnectionsPlaceholder()

            // 5. PREFERENCES
            SectionTitle("Preferences")
            PreferencesGroup {
                weekStartRow(viewModel)
                PrefRowDivider()
                PrefRow(label: "Default reminder",
                        value: ReminderOption(minutes: viewModel.defaultReminderMinutes),
                        options: ReminderOption.allCases) { newValue in
                    viewModel.setDefaultReminderMinutes(newValue.minutes)
                }
                PrefRowDivider()
                ToggleRow(label: PaperSettingsView.askThePlannerToggleLabel,
                          detail: "On-device only · keeps data private",
                          isOn: Binding(
                              get: { viewModel.appleIntelligenceEnabled },
                              set: { viewModel.setAppleIntelligenceEnabled($0) }
                          ))
                PrefRowDivider()
                ToggleRow(label: "AI Sticky Notes",
                          detail: "Smart reminders on each day page",
                          isOn: Binding(
                              get: { viewModel.aiStickyNotesEnabled },
                              set: { viewModel.setAIStickyNotesEnabled($0) }
                          ))
            }

            AboutFooter()
        }
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 28, trailing: 18))
    }

    /// Seven-day week-start menu. Matches `PrefRow` padding and type so the
    /// row sits in the preferences card; the menu (not pills) is what the
    /// week-start UI test drives.
    private func weekStartRow(_ viewModel: SettingsViewModel) -> some View {
        Menu {
            ForEach(WeekStartDay.allCases, id: \.self) { day in
                Button(day.displayName) { viewModel.setWeekStart(day) }
            }
        } label: {
            HStack(spacing: 10) {
                Text("Week starts on")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(viewModel.weekStart.displayName)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.ink2)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.ink3)
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Week starts on")
        .accessibilityValue(viewModel.weekStart.displayName)
        .accessibilityIdentifier("settings.weekstart.menu")
    }
}

// MARK: - PrefRow value types

/// Five-state option for `Default reminder`. `nil` minutes maps to "None";
/// everything else uses a compact "5 min" / "1 hr" form.
struct ReminderOption: Hashable, CaseIterable, CustomStringConvertible {
    let minutes: Int?

    static let allCases: [ReminderOption] = [
        ReminderOption(minutes: nil),
        ReminderOption(minutes: 5),
        ReminderOption(minutes: 15),
        ReminderOption(minutes: 30),
        ReminderOption(minutes: 60),
    ]

    var description: String {
        guard let minutes else { return "None" }
        if minutes == 60 { return "1 hr" }
        return "\(minutes) min"
    }
}

#Preview("PaperSettingsView · cream") {
    PaperSettingsView()
        .paperTheme(.cream)
        .environment(\.settingsStore, StubSettingsStore())
}

#Preview("PaperSettingsView · kraft") {
    PaperSettingsView()
        .paperTheme(.kraft)
        .environment(\.settingsStore, StubSettingsStore())
}

#Preview("PaperSettingsView · midnight") {
    PaperSettingsView()
        .paperTheme(.midnight)
        .environment(\.settingsStore, StubSettingsStore())
}
