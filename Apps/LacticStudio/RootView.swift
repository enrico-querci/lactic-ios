import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// Placeholder root for the coach app. Becomes a `NavigationSplitView` shell
/// once sign-in and the client list land.
struct RootView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Lactic Studio")
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
