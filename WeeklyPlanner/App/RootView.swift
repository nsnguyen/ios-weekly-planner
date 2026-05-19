import SwiftUI

/// The root scene the user lands on when the app launches. In Phase 15 this
/// view's job is intentionally tiny: read the environment-injected
/// `SettingsStoring` and hand it to `AppShell`, which owns every piece of
/// nav state (tab selection, day/week controller, modal-overlay flags).
///
/// All of the prior in-line composition — `BookContainer` wiring, modal
/// overlays, intelligence-service construction — now lives in `AppShell`.
struct RootView: View {
    @Environment(\.settingsStore) private var settingsStore

    var body: some View {
        AppShell(settingsStore: settingsStore)
    }
}

#Preview {
    RootView()
        .environment(\.eventStore, StubEventStore())
        .environment(\.inboxStore, StubInboxStore())
        .environment(\.taskStore, StubTaskStore())
}
