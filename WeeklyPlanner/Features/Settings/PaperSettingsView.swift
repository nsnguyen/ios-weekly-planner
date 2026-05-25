import SwiftUI

/// The embedded Settings page. Sits inside the leather book chrome that
/// `AppShell` paints, painting its own `BookPage` + `PaperSurface` so the
/// background gradient + ruled lines + hole punches read as a real paper
/// page. Body is a `ScrollView` of five sections plus header + footer.
///
/// `SettingsViewModel` is built lazily in `.task` so a fresh navigation
/// always reads the latest `UserSettings` row.
struct PaperSettingsView: View {
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
                PrefRow(label: "Week starts on",
                        value: viewModel.weekStartsOnMonday ? WeekStart.monday : .sunday,
                        options: WeekStart.allCases) { newValue in
                    viewModel.setWeekStartsOnMonday(newValue == .monday)
                }
                PrefRowDivider()
                PrefRow(label: "Default reminder",
                        value: ReminderOption(minutes: viewModel.defaultReminderMinutes),
                        options: ReminderOption.allCases) { newValue in
                    viewModel.setDefaultReminderMinutes(newValue.minutes)
                }
                PrefRowDivider()
                ToggleRow(label: "Apple Intelligence",
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
}

// MARK: - PrefRow value types

/// Two-state option for `Week starts on`. `CustomStringConvertible` so
/// `PrefRow` can render it directly.
enum WeekStart: String, CaseIterable, CustomStringConvertible {
    case monday, sunday
    var description: String { rawValue.capitalized }
}

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
