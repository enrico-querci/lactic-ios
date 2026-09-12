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
                // The mirror image of the client app's coach screen: roles are
                // server-controlled, and every /coach/** endpoint rejects a
                // client, so routing one into the shell would show errors
                // everywhere instead of an explanation.
                if user.role == .coach {
                    StudioClientView(user: user)
                } else {
                    StudioWrongRoleView(user: user)
                }
            }
        }
        .animation(.default, value: environment.session.phase)
        .task { await environment.session.restore() }
    }
}

/// A client signed into the coach app.
private struct StudioWrongRoleView: View {
    @Environment(StudioEnvironment.self) private var environment
    let user: User

    var body: some View {
        VStack(spacing: LacticSpacing.lg) {
            Text("This is a client account")
                .font(.lacticTitle)
            Text("Lactic Studio is for coaches. Use the Lactic app to follow your programme.")
                .font(.lacticBody)
                .foregroundStyle(LacticColor.textSecondary)
                .multilineTextAlignment(.center)
            Text(user.email)
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textMuted)
            Button("Sign out") {
                Task { await environment.session.signOut() }
            }
            .lacticButton(.secondary)
        }
        .padding(LacticSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LacticColor.surface)
    }
}

#Preview {
    RootView()
        .environment(StudioEnvironment())
}
