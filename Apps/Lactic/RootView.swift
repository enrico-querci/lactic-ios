import LacticKit
import LacticUI
import SwiftUI

/// Routes on session state.
///
/// `restoring` is a distinct case rather than a flavour of signed out so the
/// app shows a splash instead of flashing the sign-in screen at someone who
/// turns out to be signed in already.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--programme-design-preview") {
                NavigationStack { ProgrammeDesignPreview() }
            } else if ProcessInfo.processInfo.arguments.contains("--home-design-preview") {
                NavigationStack { HomeDesignPreview() }
            } else if ProcessInfo.processInfo.arguments.contains("--workout-design-preview") {
                NavigationStack { WorkoutDesignPreview() }
            } else if ProcessInfo.processInfo.arguments.contains("--history-design-preview") {
                NavigationStack { HistoryDesignPreview() }
            } else {
                sessionContent
            }
        #else
            sessionContent
        #endif
    }

    private var sessionContent: some View {
        Group {
            // Ahead of the phase switch, but behind `restoring`: the step an
            // invitation offers depends on who is signed in, and during restore
            // that is not yet known — a signed-in client would briefly be told
            // to sign in.
            if environment.session.phase != .restoring, let token = environment.pendingInvitationToken {
                InvitationView(token: token)
            } else {
                phaseContent
            }
        }
        .animation(.default, value: environment.session.phase)
        .task { await environment.session.restore() }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch environment.session.phase {
        case .restoring:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LacticColor.surface)
        case .signedOut:
            SignInView()
        case .signedIn(let user):
            // A user has exactly one role, assigned by the server. A coach
            // gets 403 from every client endpoint, so routing them into the
            // client shell shows an error on every screen instead of an
            // explanation.
            if user.role == .coach {
                CoachAccountView(user: user)
            } else {
                ClientShell()
            }
        }
    }
}
