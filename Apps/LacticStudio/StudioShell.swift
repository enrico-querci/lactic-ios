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
    /// Whether iPad shows the sidebar beside the columns. Starts open where
    /// there is width for it, and any pane's toolbar can toggle it.
    var showsSidebar = true

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

/// The coach workspace: five destinations.
///
/// On iPad a sidebar lists them and the selected one lays its list and the
/// selection side by side next to it — three columns where there is something
/// to drill into twice. On iPhone the same destinations are a bottom tab bar,
/// and the columns collapse into pushes.
@MainActor
struct StudioShell: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Passed in rather than read from the environment, so the design preview
    /// can run every tab against its fixture transport.
    let client: APIClient
    let coachName: String
    let coachEmail: String
    let roster: ClientListModel
    let signOut: () -> Void
    let deleteAccount: () async throws -> Void

    @State private var navigator = Self.initialNavigator
    @State private var hasSizedSidebar = false

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                tabs
            } else {
                sidebarLayout
            }
        }
        // On the root, not on each tab: collapsed on iPhone a split view hosts
        // its pushed columns itself, outside the environment of the column
        // that pushed them.
        .environment(navigator)
    }

    // MARK: - iPhone

    private var tabs: some View {
        @Bindable var navigator = navigator

        return TabView(selection: $navigator.tab) {
            Tab("Clients", systemImage: "person.2", value: StudioTab.clients) {
                content(for: .clients)
            }
            .badge(roster.pendingInvitations.count)
            Tab("Programmes", systemImage: "list.bullet.rectangle", value: StudioTab.programmes) {
                content(for: .programmes)
            }
            Tab("Assignments", systemImage: "calendar.badge.checkmark", value: StudioTab.assignments) {
                content(for: .assignments)
            }
            Tab("Exercises", systemImage: "dumbbell", value: StudioTab.exercises) {
                content(for: .exercises)
            }
            Tab("Account", systemImage: "person.crop.circle", value: StudioTab.account) {
                content(for: .account)
            }
        }
        .tint(LacticColor.accent)
    }

    // MARK: - iPad

    private var sidebarLayout: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                if navigator.showsSidebar {
                    StudioSidebar(pendingInvitations: roster.pendingInvitations.count)
                        .frame(width: 260)
                    Rectangle()
                        .fill(LacticColor.border)
                        .frame(width: 1)
                        .ignoresSafeArea()
                }
                content(for: navigator.tab)
                    .id(navigator.tab)
            }
            .animation(.snappy, value: navigator.showsSidebar)
            .onAppear {
                // Open in landscape; in portrait the columns want the width.
                guard !hasSizedSidebar else { return }
                hasSizedSidebar = true
                navigator.showsSidebar = Self.initialSidebar ?? (proxy.size.width >= 1100)
            }
        }
        .background(LacticColor.surface)
        .tint(LacticColor.accent)
    }

    @ViewBuilder
    private func content(for tab: StudioTab) -> some View {
        switch tab {
        case .clients:
            StudioClientsTab(client: client, roster: roster)
        case .programmes:
            StudioProgrammesTab(client: client)
        case .assignments:
            StudioAssignmentsTab(client: client)
        case .exercises:
            StudioExercisesTab(client: client)
        case .account:
            StudioAccountView(
                roster: roster, name: coachName, email: coachEmail,
                signOut: signOut, deleteAccount: deleteAccount
            )
        }
    }

    // MARK: - DEBUG deep links

    /// `--studio-destination <name>` opens a tab and `--studio-route` selects
    /// something in it — `client:<id>`, `session:<client>:<session>`,
    /// `program:<id>`, `workout:<program>:<week>:<workout>` or `exercise:<id>` —
    /// so each can be reviewed without driving the UI. The old destination
    /// names still work: `invitations` and `profile` and `plan` land on the
    /// tab that now holds them. `--studio-profile` still opens Account.
    /// `--studio-sidebar` and `--studio-no-sidebar` force the iPad sidebar open
    /// or closed.
    private static var initialSidebar: Bool? {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--studio-sidebar") {
                return true
            }
            if arguments.contains("--studio-no-sidebar") {
                return false
            }
        #endif
        return nil
    }

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
