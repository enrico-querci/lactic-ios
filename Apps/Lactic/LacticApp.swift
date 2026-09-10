import LacticKit
import LacticUI
import SwiftUI

@main
struct LacticApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(LacticColor.accent)
                .foregroundStyle(LacticColor.textPrimary)
                .environment(environment)
                // Drives the app's own strings from the in-app switcher rather
                // than the device language. Without this the client picks
                // Italiano in Settings, their coach's exercise library comes
                // back translated because the API honours Accept-Language, and
                // the surrounding interface stays in whatever language the
                // phone is set to — two languages on one screen.
                .environment(\.locale, environment.locale.foundationLocale)
            // Google's flow returns through the reversed-client-id scheme
            // declared in Info.plist.
            #if DEBUG
                .task { environment.seedInvitationFromLaunchArguments() }
            #endif
                .onOpenURL { url in
                    // Google first: it owns the reversed-client-id scheme and
                    // returns false for anything it did not issue.
                    guard !GoogleSignInProvider.handle(url) else { return }
                    environment.openInvitation(from: url)
                }
        }
    }
}
