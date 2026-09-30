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

/// The sidebar's destinations — the web's coach navigation, plus Profile.
enum StudioDestination: String, Hashable, CaseIterable {
    case clients
    case invitations
    case assignments
    case programs
    case exercises
    case templates
    case plan
    case profile
}

/// Everything a destination can drill into. Each carries enough to title the
/// screen before its data arrives.
enum StudioRoute: Hashable {
    case client(id: Int, name: String)
    case clientSession(clientID: Int, sessionID: Int, title: String)
    case program(id: Int, name: String)
    case workout(programID: Int, weekID: Int, workoutID: Int, name: String)
    case exercise(id: Int, name: String)
}

/// The current destination's drill-down stack.
///
/// A reference type held once by the shell and handed down through the
/// environment, so a screen can open something it just created. It replaces
/// a closure that was rebuilt on every render: a new closure is a new
/// environment value, which invalidated the whole detail column each time
/// the shell redrew.
@MainActor
@Observable
final class StudioNavigator {
    var path: [StudioRoute]

    init(path: [StudioRoute] = []) {
        self.path = path
    }

    func push(_ route: StudioRoute) {
        path.append(route)
    }
}

/// The iPad-first coach workspace: a sidebar of destinations, each with its
/// own drill-down stack in the detail column. On iPhone the split view
/// collapses into a list that pushes the same screens.
@MainActor
struct StudioShell: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Passed in rather than read from the environment, so the design preview
    /// can run every destination against its fixture transport.
    let client: APIClient
    let coachName: String
    let coachEmail: String
    let roster: ClientListModel
    let signOut: () -> Void
    let deleteAccount: () async throws -> Void

    @State private var selection: StudioDestination? = Self.initialDestination
    @State private var navigator = StudioNavigator(path: Self.initialPath)

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Coaching") {
                    row(.clients, "Clients", compact: "Clients", image: "person.2.fill", count: roster.clients.count)
                    row(
                        .invitations, "Invitations", compact: "Invites", image: "envelope.fill",
                        count: roster.pendingInvitations.count
                    )
                    row(.assignments, "Assignments", compact: "Assigned", image: "calendar.badge.checkmark")
                }
                Section("Library") {
                    row(.programs, "Programmes", compact: "Programmes", image: "list.bullet.rectangle.fill")
                    row(.exercises, "Exercises", compact: "Exercises", image: "dumbbell.fill")
                    row(.templates, "Templates", compact: "Templates", image: "square.on.square.fill")
                }
                Section("Account") {
                    row(.plan, "Plan", compact: "Plan", image: "creditcard.fill")
                    row(.profile, "Profile", compact: "Profile", image: "person.crop.circle.fill")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Lactic Studio")
            .navigationSplitViewColumnWidth(
                min: dynamicTypeSize.isAccessibilitySize ? 360 : 250,
                ideal: dynamicTypeSize.isAccessibilitySize ? 400 : 300,
                max: dynamicTypeSize.isAccessibilitySize ? 440 : 360
            )
        } detail: {
            NavigationStack(path: $navigator.path) {
                root(for: selection ?? .clients)
                    .navigationDestination(for: StudioRoute.self, destination: screen)
            }
            // Deliberately no `.id(selection)` here. On iPhone, where the split
            // view collapses, it rebuilt the whole stack as the detail was
            // pushed; the destination's view kept disappearing and reappearing,
            // each time cancelling its load and starting another. With real
            // network latency that never converged: 122 requests in five
            // seconds to /coach/program_assignments behind an endless spinner.
            // Each destination is a different view type, so its state is
            // already separate; the path is reset below instead.
        }
        .navigationSplitViewStyle(.balanced)
        // On the split view, not the detail's stack: collapsed on iPhone, the
        // split view hosts the pushed screens itself, outside that stack's
        // environment, and the programme builder trapped reading a navigator
        // that was never there.
        .environment(navigator)
        .onChange(of: selection) { navigator.path = [] }
    }

    private func row(
        _ destination: StudioDestination, _ title: LocalizedStringKey, compact: LocalizedStringKey,
        image: String, count: Int? = nil
    ) -> some View {
        StudioSidebarRow(title: title, compactTitle: compact, systemImage: image, count: count)
            .tag(destination)
    }

    @ViewBuilder
    private func root(for destination: StudioDestination) -> some View {
        switch destination {
        case .clients:
            StudioClientsDashboard(model: roster)
        case .invitations:
            StudioInvitationsDashboard(model: roster)
        case .assignments:
            StudioAssignmentsView(client: client)
        case .programs:
            StudioProgramsView(client: client)
        case .exercises:
            StudioExercisesView(client: client)
        case .templates:
            StudioTemplatesView(client: client)
        case .plan:
            StudioPlanView(roster: roster)
        case .profile:
            StudioProfileView(name: coachName, email: coachEmail, signOut: signOut, deleteAccount: deleteAccount)
        }
    }

    @ViewBuilder
    private func screen(for route: StudioRoute) -> some View {
        switch route {
        case .client(let id, let name):
            StudioClientDetailView(client: client, clientID: id, name: name, roster: roster)
        case .clientSession(let clientID, let sessionID, let title):
            StudioClientSessionView(client: client, clientID: clientID, sessionID: sessionID, title: title)
        case .program(let id, let name):
            StudioProgramBuilderView(client: client, programID: id, name: name)
        case .workout(let programID, let weekID, let workoutID, let name):
            StudioWorkoutEditorView(
                client: client, programID: programID, weekID: weekID, workoutID: workoutID, name: name
            )
        case .exercise(let id, let name):
            StudioExerciseDetailView(client: client, exerciseID: id, name: name)
        }
    }

    // MARK: - DEBUG deep links

    /// `--studio-destination <name>` opens a destination and `--studio-route`
    /// pushes a screen — `client:<id>`, `session:<client>:<session>`,
    /// `program:<id>` or `workout:<program>:<week>:<workout>` — so each can be
    /// reviewed without driving the sidebar. The older `--studio-profile` still
    /// opens Profile.
    private static var initialDestination: StudioDestination {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--studio-profile") {
                return .profile
            }
            if let index = arguments.firstIndex(of: "--studio-destination"), arguments.indices.contains(index + 1) {
                return StudioDestination(rawValue: arguments[index + 1]) ?? .clients
            }
        #endif
        return .clients
    }

    private static var initialPath: [StudioRoute] {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "--studio-route"), arguments.indices.contains(index + 1)
            else { return [] }
            let parts = arguments[index + 1].split(separator: ":").map(String.init)
            switch (parts.first, parts.dropFirst().compactMap { Int($0) }) {
            case ("client", let ids) where ids.count == 1:
                return [.client(id: ids[0], name: "")]
            case ("session", let ids) where ids.count == 2:
                return [.client(id: ids[0], name: ""), .clientSession(clientID: ids[0], sessionID: ids[1], title: "")]
            case ("program", let ids) where ids.count == 1:
                return [.program(id: ids[0], name: "")]
            case ("exercise", let ids) where ids.count == 1:
                return [.exercise(id: ids[0], name: "")]
            case ("workout", let ids) where ids.count == 3:
                return [
                    .program(id: ids[0], name: ""),
                    .workout(programID: ids[0], weekID: ids[1], workoutID: ids[2], name: ""),
                ]
            default:
                return []
            }
        #else
            return []
        #endif
    }
}
