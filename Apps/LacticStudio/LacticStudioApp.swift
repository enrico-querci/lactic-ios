import LacticCore
import LacticKit
import LacticUI
import SwiftUI

@main
struct LacticStudioApp: App {
    /// Constructed once and never replaced, so the session survives view
    /// identity changes.
    @State private var environment = StudioEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(LacticColor.accent)
                .foregroundStyle(LacticColor.textPrimary)
                .environment(environment)
                // The app's own language choice, not the device's, so a coach
                // does not get their client's exercise library in the wrong one.
                .environment(\.locale, environment.locale.foundationLocale)
                // Google's flow returns through the reversed-client-id scheme
                // declared in Info.plist.
                .onOpenURL { url in
                    GoogleSignInProvider.handle(url)
                }
        }
    }
}
