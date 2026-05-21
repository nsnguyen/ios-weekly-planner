import MessageUI
import SwiftUI

/// The real Connections card — replaces Phase 16's `ConnectionsPlaceholder`
/// body. Three rows separated by 0.5pt rules: Gmail (interactive — drives
/// `ConnectionsViewModel`), Apple Mail (read-only status based on
/// `MFMailComposeViewController.canSendMail()`), Google Calendar ("Coming
/// soon", disabled).
struct ConnectionsSection: View {
    @Environment(\.paperTheme) private var theme
    @Environment(\.googleAuthService) private var auth
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.inboxStore) private var inboxStore

    @State private var viewModel: ConnectionsViewModel?
    @State private var showDisconnectConfirm = false

    var body: some View {
        // The SECTION TITLE for "Connections" is rendered by `PaperSettingsView`
        // (the call site that wraps each section). This view returns just the
        // card so we don't duplicate the eyebrow + heading.
        card
        .task {
            if viewModel == nil {
                viewModel = ConnectionsViewModel(
                    settingsStore: settingsStore,
                    inboxStore: inboxStore,
                    auth: auth
                )
            }
        }
        .alert(item: alertBinding) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog(
            "Disconnect Gmail?",
            isPresented: $showDisconnectConfirm,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) { Task { await viewModel?.disconnectGmail() } }
            Button("Cancel", role: .cancel) { viewModel?.refreshFromSettings() }
        } message: {
            Text("Pending inbox suggestions for this account will be removed.")
        }
    }

    // MARK: - Card body

    private var card: some View {
        VStack(spacing: 0) {
            gmailRow
            Divider().background(theme.rule).frame(height: 0.5)
            appleMailRow
            Divider().background(theme.rule).frame(height: 0.5)
            googleCalRow
        }
        .background(theme.creamHi)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).strokeBorder(theme.rule, lineWidth: 0.5)
        )
        .padding(.bottom, 14)
    }

    // MARK: - Rows

    private var gmailRow: some View {
        ConnectionRow(
            logo: { GmailBrandLogo() },
            label: "Gmail",
            detail: gmailDetail,
            isOn: gmailToggleBinding
        )
    }

    private var appleMailRow: some View {
        let connected = MFMailComposeViewController.canSendMail()
        return ConnectionRow(
            logo: { AppleBrandLogo() },
            label: "Apple Mail",
            detail: connected ? "Connected · iCloud" : "Sign in to Mail in iOS Settings",
            isOn: .constant(connected),
            isEnabled: false,
            onTap: { viewModel?.alert = .appleMailManagedByiOS }
        )
    }

    private var googleCalRow: some View {
        ConnectionRow(
            logo: { GoogleCalLogo() },
            label: "Google Calendar",
            detail: "Coming soon",
            isOn: .constant(false),
            isEnabled: false
        )
    }

    // MARK: - Bindings

    private var gmailDetail: String {
        if let vm = viewModel, vm.isGmailConnected, let email = vm.gmailAccountEmail {
            return "\(email) · syncing events"
        }
        return "Tap to connect — pulls events & reminders from your inbox"
    }

    private var gmailToggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.isGmailConnected ?? false },
            set: { newValue in
                guard let vm = viewModel else { return }
                if newValue, vm.isGmailConnected == false {
                    Task { await vm.connectGmail(presenter: topPresenter()) }
                } else if newValue == false, vm.isGmailConnected {
                    showDisconnectConfirm = true
                }
            }
        )
    }

    private var alertBinding: Binding<ConnectionsAlert?> {
        Binding(get: { viewModel?.alert }, set: { viewModel?.alert = $0 })
    }

    /// Resolves the active key window's root view controller for the SDK to
    /// present the OAuth sheet from. Avoids Scene Delegate footguns by walking
    /// `UIApplication.shared.connectedScenes`.
    @MainActor
    private func topPresenter() -> UIViewController {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })
        return keyWindow?.rootViewController ?? UIViewController()
    }
}

extension ConnectionsAlert: Identifiable {
    var id: String { title + message }

    static let appleMailManagedByiOS = ConnectionsAlert(
        title: "Apple Mail",
        message: "Apple Mail is managed by iOS Settings."
    )
}
