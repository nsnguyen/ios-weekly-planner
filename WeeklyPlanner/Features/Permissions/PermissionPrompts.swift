import EventKit
import SwiftUI
import UIKit

/// Reusable shell for the "X permission is needed, open Settings" affordance.
/// Phase 16 / 17 styles this into the actual Settings screen; for now it
/// renders as a plain card so Phase 04 can wire the deep-link behavior.
struct PermissionDeniedCard: View {
    let title: String
    let message: String
    let openSettingsAction: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Open Settings", action: openSettingsAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Pre-built copy for the two permissions we'll prompt for in v1.
enum PermissionPrompts {
    @MainActor
    static func calendarDeniedCard(openSettingsAction: @escaping @MainActor () -> Void) -> PermissionDeniedCard {
        PermissionDeniedCard(title: "Calendar access needed",
                             message:
                             "Weekly Planner mirrors your events to and from the iOS Calendar. "
                                 + "Allow Calendar access in Settings to sync.",
                             openSettingsAction: openSettingsAction)
    }

    @MainActor
    static func remindersDeniedCard(openSettingsAction: @escaping @MainActor () -> Void) -> PermissionDeniedCard {
        PermissionDeniedCard(title: "Reminders access needed",
                             message: "Tasks sync with Apple Reminders. Allow Reminders access in Settings to enable sync.",
                             openSettingsAction: openSettingsAction)
    }

    /// Standard deep-link into the app's Settings page.
    @MainActor
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    VStack(spacing: 16) {
        PermissionPrompts.calendarDeniedCard(openSettingsAction: {})
        PermissionPrompts.remindersDeniedCard(openSettingsAction: {})
    }
    .padding()
}
