import SwiftData
import SwiftUI

/// The app entry point. Boots a single `ModelContainer`, constructs the
/// production `SwiftDataEventStore` / `SwiftDataInboxStore` /
/// `SwiftDataTaskStore` / `SwiftDataSettingsStore`, and (in DEBUG builds
/// only) seeds the container from bundled JSON the first time the schema
/// is empty. Stores are then injected into the environment so any view
/// subtree can read events, inbox suggestions, to-dos, or settings without
/// prop drilling.
///
/// `App` is `@MainActor` by SwiftUI convention, which is what lets
/// `init` legally call `SwiftDataStack.production` and friends — all the
/// store types are also main-actor isolated.
@main
struct WeeklyPlannerApp: App {
    @State private var container: ModelContainer
    @State private var eventStore: any EventStoring
    @State private var inboxStore: any InboxStoring
    @State private var taskStore: any TaskStoring
    @State private var settingsStore: any SettingsStoring
    @State private var googleAuthService: any GoogleAuthService
    @State private var gmailClient: GmailClient
    @State private var inboxSyncEngine: InboxSyncEngine
    @State private var bgRefreshScheduler: BackgroundRefreshScheduler

    init() {
        let container = SwiftDataStack.production
        let eventStore = SwiftDataEventStore(context: container.mainContext)
        let taskStore = SwiftDataTaskStore(context: container.mainContext)
        let settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        let googleAuthService = LiveGoogleAuthService(
            config: .fromBundle(),
            client: RealGIDSigningClient(),
            keychain: TokenKeychainStore<GoogleAccountInfo>(
                serviceID: "com.weeklyplanner.WeeklyPlanner.google"
            )
        )
        #if DEBUG
            SeedLoader.seedIfEmpty(context: container.mainContext)
        #endif
        // Rebuild the inbox store now that eventStore + settingsStore are
        // available — the accept-flow needs them to mirror to EventKit.
        let wiredInboxStore = SwiftDataInboxStore(
            context: container.mainContext,
            eventStore: eventStore,
            settingsStore: settingsStore
        )
        let gmailClient = GmailClient(auth: googleAuthService, session: URLSession.shared)
        let extractor: any EventExtractor = LiveEventExtractor()
        let syncEngine = InboxSyncEngine(
            client: gmailClient,
            extractor: extractor,
            inboxStore: wiredInboxStore,
            deltaSync: GmailDeltaSync(settingsStore: settingsStore)
        )
        let scheduler = BackgroundRefreshScheduler(engine: syncEngine)
        scheduler.registerHandler()
        _container = State(initialValue: container)
        _eventStore = State(initialValue: eventStore)
        _inboxStore = State(initialValue: wiredInboxStore)
        _taskStore = State(initialValue: taskStore)
        _settingsStore = State(initialValue: settingsStore)
        _googleAuthService = State(initialValue: googleAuthService)
        _gmailClient = State(initialValue: gmailClient)
        _inboxSyncEngine = State(initialValue: syncEngine)
        _bgRefreshScheduler = State(initialValue: scheduler)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.eventStore, eventStore)
                .environment(\.inboxStore, inboxStore)
                .environment(\.taskStore, taskStore)
                .environment(\.settingsStore, settingsStore)
                .environment(\.googleAuthService, googleAuthService)
                .environment(\.gmailClient, gmailClient)
                .environment(\.inboxSyncEngine, inboxSyncEngine)
                .modelContainer(container)
                .onOpenURL { url in
                    _ = RealGIDSigningClient().handle(url: url)
                }
        }
    }
}
