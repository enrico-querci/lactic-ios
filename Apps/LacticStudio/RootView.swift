import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// Placeholder root. Replaced by the sign-in / shell split once `AuthService`
/// and the feature screens land.
struct RootView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Lactic Studio")
                .font(.largeTitle.bold())
            Text("Coach")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RootView()
}
