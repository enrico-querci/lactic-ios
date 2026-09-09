import LacticUI
import SwiftUI

/// The signed-in client experience.
///
/// Four tabs rather than the web's collapsing top nav: on a phone a tab bar is
/// the expected shape, and the destinations are peers rather than a hierarchy.
struct ClientShell: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            Tab("Programmes", systemImage: "list.bullet.rectangle") {
                ProgramsView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistoryView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tint(LacticColor.accent)
    }
}
