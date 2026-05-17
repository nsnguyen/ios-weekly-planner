import SwiftUI

struct RootView: View {
    var body: some View {
        ZStack {
            // #F2F2F7 — iOS systemGray6 light. Placeholder background for Phase 01.
            Color(red: 242.0 / 255.0, green: 242.0 / 255.0, blue: 247.0 / 255.0)
                .ignoresSafeArea()

            Text("Weekly Planner — bootstrap")
                .font(.system(.body))
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    RootView()
}
