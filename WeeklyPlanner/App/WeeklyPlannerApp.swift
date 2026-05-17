import SwiftData
import SwiftUI

/// The app entry point. Boots a single `ModelContainer`, constructs the
/// production `SwiftDataEventStore` / `SwiftDataInboxStore`, and (in DEBUG
/// builds only) seeds the container from bundled JSON the first time the
/// schema is empty. Stores are then injected into the environment so any
/// view subtree can read events / inbox suggestions without prop drilling.
///
/// `App` is `@MainActor` by SwiftUI convention, which is what lets
/// `init` legally call `SwiftDataStack.production` and friends — all the
/// store types are also main-actor isolated.
@main
struct WeeklyPlannerApp: App {
    @State private var container: ModelContainer
    @State private var eventStore: any EventStoring
    @State private var inboxStore: any InboxStoring

    init() {
        let container = SwiftDataStack.production
        let eventStore = SwiftDataEventStore(context: container.mainContext)
        let inboxStore = SwiftDataInboxStore(context: container.mainContext)
        #if DEBUG
            SeedLoader.seedIfEmpty(context: container.mainContext)
        #endif
        _container = State(initialValue: container)
        _eventStore = State(initialValue: eventStore)
        _inboxStore = State(initialValue: inboxStore)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.eventStore, eventStore)
                .environment(\.inboxStore, inboxStore)
                .modelContainer(container)
        }
    }
}
