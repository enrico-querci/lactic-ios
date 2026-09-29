import LacticUI
import SwiftUI

/// The signed-in client experience.
///
/// Tabs rather than the web's collapsing top nav: on a phone a tab bar is
/// the expected shape, and the destinations are peers rather than a hierarchy.
struct ClientShell: View {
    private enum Destination: Hashable {
        case home, programmes, history, profile, settings
    }

    @State private var selection = Self.initialDestination

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: Destination.home) {
                HomeView()
            }
            Tab("Programmes", systemImage: "list.bullet.rectangle", value: Destination.programmes) {
                ProgramsView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: Destination.history) {
                HistoryView()
            }
            Tab("Profile", systemImage: "person.crop.circle", value: Destination.profile) {
                ProfileView()
            }
            Tab("Settings", systemImage: "gearshape", value: Destination.settings) {
                SettingsView()
            }
        }
        .tint(LacticColor.accent)
    }

    /// `--profile-tab` opens on Profile, so the screen can be reviewed
    /// without driving the tab bar.
    private static var initialDestination: Destination {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--profile-tab") {
                return .profile
            }
        #endif
        return .home
    }
}
