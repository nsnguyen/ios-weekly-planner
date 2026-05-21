import SwiftUI

/// Phase 16 left this file as a placeholder. Phase 17 keeps the type so
/// `PaperSettingsView`'s call-site (`ConnectionsPlaceholder()`) doesn't churn
/// — the body now simply forwards to the real `ConnectionsSection`. A future
/// refactor (Phase 22 polish) can rename the call-site and delete this
/// shim.
struct ConnectionsPlaceholder: View {
    var body: some View {
        ConnectionsSection()
    }
}

#Preview("ConnectionsPlaceholder") {
    ConnectionsPlaceholder()
        .padding()
        .background(PaperTheme.cream.cream)
        .paperTheme(.cream)
}
