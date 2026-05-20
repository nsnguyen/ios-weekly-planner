import XCTest
import SwiftData
@testable import WeeklyPlanner

@MainActor
final class ConnectionsSectionTests: XCTestCase {

    // MARK: - ConnectionsAlert factory

    func testAlertConnectFailedShape() {
        let a = ConnectionsAlert.connectFailed
        XCTAssertEqual(a.title, "Couldn't connect Gmail")
        XCTAssertFalse(a.message.isEmpty)
    }

    func testAlertNotConfiguredMentionsSecretsFile() {
        let a = ConnectionsAlert.notConfigured
        XCTAssertEqual(a.title, "Gmail isn't configured")
        XCTAssertTrue(a.message.contains("Secrets.xcconfig"))
    }

    func testAlertAppleMailMentionsiOSSettings() {
        let a = ConnectionsAlert.appleMailManagedByiOS
        XCTAssertEqual(a.title, "Apple Mail")
        XCTAssertTrue(a.message.contains("iOS Settings"))
    }

    // MARK: - gmailDidConnect notification

    func testGmailDidConnectNotificationName() {
        XCTAssertEqual(
            Notification.Name.gmailDidConnect.rawValue,
            "WeeklyPlanner.gmailDidConnect"
        )
    }

    // MARK: - View-model detail line via container

    func testGmailDetailTextWhenDisconnected() async throws {
        let vm = makeViewModel(connected: false, email: nil)
        XCTAssertFalse(vm.isGmailConnected)
        XCTAssertNil(vm.gmailAccountEmail)
    }

    func testGmailDetailTextWhenConnected() async throws {
        let vm = makeViewModel(connected: true, email: "sara@gmail.com")
        XCTAssertTrue(vm.isGmailConnected)
        XCTAssertEqual(vm.gmailAccountEmail, "sara@gmail.com")
    }

    // MARK: - Helpers

    private func makeViewModel(connected: Bool, email: String?) -> ConnectionsViewModel {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: UserSettings.self, InboxSuggestion.self, Event.self, TaskItem.self,
            configurations: config
        )
        let settingsStore = SwiftDataSettingsStore(context: container.mainContext)
        try! settingsStore.update { s in
            s.gmailConnected = connected
            s.gmailAccountEmail = email
        }
        return ConnectionsViewModel(
            settingsStore: settingsStore,
            inboxStore: SwiftDataInboxStore(context: container.mainContext),
            auth: StubGoogleAuthService()
        )
    }
}
