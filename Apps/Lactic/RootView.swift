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
        Group {
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
        .animation(.default, value: environment.session.phase)
        .task { await environment.session.restore() }
    }
}
