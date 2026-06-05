import SwiftData
import SwiftUI
import UserNotifications

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
    @UIApplicationDelegateAdaptor(NotificationsAppDelegate.self) private var appDelegate

    @State private var container: ModelContainer
    @State private var eventStore: any EventStoring
    @State private var inboxStore: any InboxStoring
    @State private var taskStore: any TaskStoring
    @State private var noteStore: any NoteStoring
    @State private var settingsStore: any SettingsStoring
    @State private var googleAuthService: any GoogleAuthService
    @State private var gmailClient: GmailClient
    @State private var inboxSyncEngine: InboxSyncEngine
    @State private var bgRefreshScheduler: BackgroundRefreshScheduler
    @State private var eventKitAuth: EventKitAuthorization

    // MARK: Phase 19 — notifications wiring
    @State private var notificationCenter: any NotificationCentering
    @State private var notificationAuth: NotificationAuthorization
    @State private var locationManager: LocationReminderManager
    @State private var eventScheduler: EventNotificationScheduler
    @State private var taskScheduler: TaskNotificationScheduler
    @State private var rescheduleObserver: NotificationReschedulingObserver
    @State private var deepLinkRouter: DeepLinkRouter

    init() {
        let container = SwiftDataStack.production
        let baseEventStore = SwiftDataEventStore(context: container.mainContext)
        let taskStore = SwiftDataTaskStore(context: container.mainContext)
        let noteStore = SwiftDataNoteStore(context: container.mainContext)
        let settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        let googleAuthService = LiveGoogleAuthService(
            config: .fromBundle(),
            client: RealGIDSigningClient(),
            keychain: TokenKeychainStore<GoogleAccountInfo>(
                serviceID: "com.weeklyplanner.WeeklyPlanner.google"
            )
        )
        // Wire the Phase 04 EventKit decorator. SystemEventKitGateway wraps
        // EKEventStore; the decorator mirrors every write into the user's iOS
        // Calendar once permission is granted. Without this, accept-flow
        // writes land in SwiftData only — not visible in Calendar.app.
        let eventKitGateway = SystemEventKitGateway()
        let calendarManager = CategoryCalendarManager(gateway: eventKitGateway)
        let eventKitAuth = EventKitAuthorization(gateway: eventKitGateway)
        let eventStore: any EventStoring = EventKitMirroringEventStore(
            base: baseEventStore,
            gateway: eventKitGateway,
            calendarManager: calendarManager
        )
        #if DEBUG
            SeedLoader.seedIfEmpty(context: container.mainContext)
        #endif
        // MARK: Phase 19 — notifications wiring
        // Constructed before wiredInboxStore so authWrapper can be injected
        // into the inbox store for the first-event permission probe.
        let center: any NotificationCentering = LiveNotificationCenter()
        let authWrapper = NotificationAuthorization(center: center)

        // Rebuild the inbox store now that eventStore + settingsStore are
        // available — the accept-flow needs them to mirror to EventKit.
        let wiredInboxStore = SwiftDataInboxStore(
            context: container.mainContext,
            eventStore: eventStore,
            settingsStore: settingsStore,
            notificationAuth: authWrapper
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
        let location = LiveLocationManager()
        let locationMgr = LocationReminderManager(location: location, center: center)
        let eventSched = EventNotificationScheduler(center: center,
                                                    locationRegistrar: locationMgr,
                                                    eventStore: eventStore)
        let taskSched = TaskNotificationScheduler(center: center,
                                                  locationRegistrar: locationMgr,
                                                  taskStore: taskStore)
        let rescheduler = NotificationReschedulingObserver(eventScheduler: eventSched,
                                                           taskScheduler: taskSched)
        let router = DeepLinkRouter()

        _container = State(initialValue: container)
        _eventStore = State(initialValue: eventStore)
        _inboxStore = State(initialValue: wiredInboxStore)
        _taskStore = State(initialValue: taskStore)
        _noteStore = State(initialValue: noteStore)
        _settingsStore = State(initialValue: settingsStore)
        _googleAuthService = State(initialValue: googleAuthService)
        _gmailClient = State(initialValue: gmailClient)
        _inboxSyncEngine = State(initialValue: syncEngine)
        _bgRefreshScheduler = State(initialValue: scheduler)
        _eventKitAuth = State(initialValue: eventKitAuth)
        _notificationCenter = State(initialValue: center)
        _notificationAuth = State(initialValue: authWrapper)
        _locationManager = State(initialValue: locationMgr)
        _eventScheduler = State(initialValue: eventSched)
        _taskScheduler = State(initialValue: taskSched)
        _rescheduleObserver = State(initialValue: rescheduler)
        _deepLinkRouter = State(initialValue: router)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.eventStore, eventStore)
                .environment(\.inboxStore, inboxStore)
                .environment(\.taskStore, taskStore)
                .environment(\.noteStore, noteStore)
                .environment(\.settingsStore, settingsStore)
                .environment(\.googleAuthService, googleAuthService)
                .environment(\.gmailClient, gmailClient)
                .environment(\.inboxSyncEngine, inboxSyncEngine)
                .environment(\.notificationCenter, notificationCenter)
                .environment(\.eventNotificationScheduler, eventScheduler)
                .environment(\.taskNotificationScheduler, taskScheduler)
                .environment(\.locationReminderManager, locationManager)
                .environment(\.deepLinkRouter, deepLinkRouter)
                .modelContainer(container)
                .onOpenURL { url in
                    _ = RealGIDSigningClient().handle(url: url)
                }
                .task {
                    // Prompt for Calendar access on first launch so the
                    // EventKit decorator can mirror accepted suggestions
                    // (and any future Event writes) into the system Calendar.
                    await eventKitAuth.requestEventsIfNeeded()
                    // Hand the delegate the live references it needs to route taps.
                    appDelegate.router = deepLinkRouter
                    appDelegate.taskStore = taskStore
                    appDelegate.center = notificationCenter
                    // Probe authorization once on launch so the denied-banner
                    // in ConnectionsSection has accurate state on first render.
                    _ = await notificationAuth.status()
                }
        }
    }
}
