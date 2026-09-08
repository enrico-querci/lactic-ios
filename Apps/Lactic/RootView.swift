import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// Placeholder root while the client experience is built out. Replaced by the
/// sign-in / tab-shell split once `AuthService` lands.
struct RootView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Lactic")
                .font(.largeTitle.bold())
            Text("Core \(LacticCore.version) · Kit \(LacticKit.version) · UI \(LacticUI.version)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RootView()
}
