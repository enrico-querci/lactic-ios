import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// Routes on session state, mirroring the client app.
struct RootView: View {
    @Environment(StudioEnvironment.self) private var environment

    var body: some View {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--studio-design-preview") {
                if ProcessInfo.processInfo.arguments.contains("--studio-sign-in") {
                    StudioSignInView()
                } else {
                    StudioDesignPreview()
                }
            } else {
                sessionContent
            }
        #else
            sessionContent
        #endif
    }

    private var sessionContent: some View {
        Group {
            switch environment.session.phase {
            case .restoring:
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LacticColor.surface)
            case .signedOut:
                StudioSignInView()
            case .signedIn(let user):
                // Always a coach: the session is scoped to this app, so a
                // client is refused at sign-in and signed out on restore.
                StudioWorkspace(user: user)
            }
        }
        .animation(.default, value: environment.session.phase)
        .task {
            await environment.session.restore()
            #if DEBUG
                await environment.signInFromLaunchArguments()
            #endif
        }
    }
}

#Preview {
    RootView()
        .environment(StudioEnvironment())
}
