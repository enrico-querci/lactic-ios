import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// Placeholder root. Replaced by the sign-in / shell split once `AuthService`
/// and the feature screens land.
struct RootView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Lactic")
                .font(.largeTitle.bold())
            Text("Client")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RootView()
}
