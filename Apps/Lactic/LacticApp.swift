import LacticKit
import SwiftUI

@main
struct LacticApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                // Drives the app's own strings from the in-app switcher rather
                // than the device language. Without this the client picks
                // Italiano in Settings, their coach's exercise library comes
                // back translated because the API honours Accept-Language, and
                // the surrounding interface stays in whatever language the
                // phone is set to — two languages on one screen.
                .environment(\.locale, environment.locale.foundationLocale)
        }
    }
}
