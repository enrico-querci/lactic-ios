import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// Routes on session state, mirroring the client app.
///
/// The signed-in surface is still a placeholder: Studio v1 is sign-in plus a
/// client list, and the iPad layout is the visual pass's to design. What is
/// real here is the auth path — `CoachAPI` exists, the credentials are wired,
/// and a coach can get a token.
struct RootView: View {
    @Environment(StudioEnvironment.self) private var environment

    var body: some View {
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
                    StudioPlaceholderView(user: user)
                } else {
                    StudioWrongRoleView(user: user)
                }
            }
        }
        .animation(.default, value: environment.session.phase)
        .task { await environment.session.restore() }
    }
}

/// Signed in as a coach. Awaiting the client list and the iPad split view.
private struct StudioPlaceholderView: View {
    @Environment(StudioEnvironment.self) private var environment
    let user: User

    var body: some View {
        VStack(spacing: LacticSpacing.lg) {
            Image(systemName: "dumbbell.fill")
                .font(.lacticDisplay)
                .foregroundStyle(LacticColor.brand)
                .accessibilityHidden(true)
            Text("Lactic Studio")
                .font(.lacticDisplay)
            Text(user.name)
                .font(.lacticBody)
            Button("Sign out") {
                Task { await environment.session.signOut() }
            }
            .lacticButton(.secondary)
        }
        .foregroundStyle(LacticColor.textOnHero)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LacticColor.heroSurface)
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
