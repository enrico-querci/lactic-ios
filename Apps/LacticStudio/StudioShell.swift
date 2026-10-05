import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// Signed-in Studio: builds the roster model the shell shares between
/// destinations, then hands over to the shell.
struct StudioWorkspace: View {
    @Environment(StudioEnvironment.self) private var environment

    let user: User
    @State private var roster: ClientListModel?

    var body: some View {
        Group {
            if let roster {
                StudioShell(
                    client: environment.client,
                    coachName: user.name,
                    coachEmail: user.email,
                    roster: roster,
                    signOut: { Task { await environment.session.signOut() } },
                    deleteAccount: {
                        try await environment.client.sendIgnoringResponse(CoachAPI.deleteAccount)
                        // The account is gone, so there is no session left to
                        // revoke: clear locally rather than calling DELETE /auth.
                        await environment.session.clearSession()
                    }
                )
            } else {
                LoadingView(String(localized: "Loading your workspace"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LacticColor.surface)
            }
        }
        .task {
            guard roster == nil else { return }
            let roster = ClientListModel(client: environment.client)
            self.roster = roster
            await roster.load()
        }
    }
}

/// The top-level tabs. Each is a workspace of its own: a list, and the thing
/// selected in it beside the list on iPad, pushed over it on iPhone.
enum StudioTab: String, Hashable, CaseIterable {
    case clients
    case programmes
    case assignments
    case exercises
    case account
}

/// A workout inside its week, which every workout endpoint needs in its path.
struct StudioWorkoutKey: Hashable {
    let weekID: Int
    let workoutID: Int
}

/// What is selected in each tab.
///
/// A reference type held once by the shell and handed down through the
/// environment, so a screen in one tab can open something in another — an
/// assignment's client, a new programme's builder. Selection lives here rather
/// than in each tab's `@State` for the same reason.
@MainActor
@Observable
final class StudioNavigator {
    var tab: StudioTab

    var clientID: Int?
    var sessionID: Int?
    var programmeID: Int?
    var workout: StudioWorkoutKey?
    var exerciseID: Int?

    init(tab: StudioTab = .clients) {
        self.tab = tab
    }

    func openClient(_ id: Int) {
        sessionID = nil
        clientID = id
        tab = .clients
    }

    func openProgramme(_ id: Int) {
        workout = nil
        programmeID = id
        tab = .programmes
    }
}

/// The coach workspace: five tabs. On iPad they sit in a tab bar that folds
/// into a sidebar, and each one lays its list and the selected item side by
/// side — three columns where there is something to drill into twice. On
/// iPhone the tabs are a bottom bar and the columns collapse into pushes.
@MainActor
struct StudioShell: View {
    /// Passed in rather than read from the environment, so the design preview
    /// can run every tab against its fixture transport.
    let client: APIClient
    let coachName: String
    let coachEmail: String
    let roster: ClientListModel
    let signOut: () -> Void
    let deleteAccount: () async throws -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var navigator = Self.initialNavigator

    var body: some View {
        @Bindable var navigator = navigator

        TabView(selection: $navigator.tab) {
            Tab("Clients", systemImage: "person.2", value: StudioTab.clients) {
                StudioClientsTab(client: client, roster: roster)
            }

            Tab("Programmes", systemImage: "list.bullet.rectangle", value: StudioTab.programmes) {
                StudioProgrammesTab(client: client)
            }

            Tab("Assignments", systemImage: "calendar.badge.checkmark", value: StudioTab.assignments) {
                StudioAssignmentsTab(client: client)
            }

            Tab("Exercises", systemImage: "dumbbell", value: StudioTab.exercises) {
                StudioExercisesTab(client: client)
            }

            Tab("Account", systemImage: "person.crop.circle", value: StudioTab.account) {
                StudioAccountView(
                    roster: roster, name: coachName, email: coachEmail,
                    signOut: signOut, deleteAccount: deleteAccount
                )
            }
            // iPad's tab bar has room for four titles, not five: there Account
            // is reached from the sidebar the bar folds into.
            .defaultVisibility(horizontalSizeClass == .compact ? .automatic : .hidden, for: .tabBar)
        }
        .tabViewStyle(.sidebarAdaptable)
        // On the tab view, not on each tab: collapsed on iPhone a split view
        // hosts its pushed columns itself, outside the environment of the
        // column that pushed them.
        .environment(navigator)
    }

    // MARK: - DEBUG deep links

    /// `--studio-destination <name>` opens a tab and `--studio-route` selects
    /// something in it — `client:<id>`, `session:<client>:<session>`,
    /// `program:<id>`, `workout:<program>:<week>:<workout>` or `exercise:<id>` —
    /// so each can be reviewed without driving the UI. The old destination
    /// names still work: `invitations` and `profile` and `plan` land on the
    /// tab that now holds them. `--studio-profile` still opens Account.
    private static var initialNavigator: StudioNavigator {
        let navigator = StudioNavigator()
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--studio-profile") {
                navigator.tab = .account
            }
            if let index = arguments.firstIndex(of: "--studio-destination"), arguments.indices.contains(index + 1) {
                navigator.tab = switch arguments[index + 1] {
                case "invitations": .clients
                case "programs", "programmes", "templates": .programmes
                case "assignments": .assignments
                case "exercises": .exercises
                case "plan", "profile", "account": .account
                default: .clients
                }
            }
            if let index = arguments.firstIndex(of: "--studio-route"), arguments.indices.contains(index + 1) {
                let parts = arguments[index + 1].split(separator: ":").map(String.init)
                let ids = parts.dropFirst().compactMap { Int($0) }
                switch (parts.first, ids.count) {
                case ("client", 1):
                    navigator.openClient(ids[0])
                case ("session", 2):
                    navigator.openClient(ids[0])
                    navigator.sessionID = ids[1]
                case ("program", 1):
                    navigator.openProgramme(ids[0])
                case ("workout", 3):
                    navigator.openProgramme(ids[0])
                    navigator.workout = StudioWorkoutKey(weekID: ids[1], workoutID: ids[2])
                case ("exercise", 1):
                    navigator.tab = .exercises
                    navigator.exerciseID = ids[0]
                default:
                    break
                }
            }
        #endif
        return navigator
    }
}
