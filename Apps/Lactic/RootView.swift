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
        .task {
            await environment.session.restore()
            #if DEBUG
                await environment.signInFromLaunchArguments()
            #endif
            // Only now is there a token to authenticate the queued writes.
            environment.drainOutbox()
        }
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
        case .signedIn:
            // Always a client: the session is scoped to this app, so a coach
            // is refused at sign-in and signed out on restore.
            ClientShell()
        }
    }
}
