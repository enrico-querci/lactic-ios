import LacticKit
import LacticUI
import SwiftUI

/// Coach sign-in.
///
/// Unstyled beyond the shared tokens: the visual pass for Studio has not
/// happened, and the shape worth keeping is the auth path, not the layout.
struct StudioSignInView: View {
    @Environment(StudioEnvironment.self) private var environment

    @State private var isSigningIn = false
    @State private var errorMessage: String?
    #if DEBUG
        @State private var devEmail = "john@example.com"
    #endif

    var body: some View {
        VStack(spacing: LacticSpacing.lg) {
            Text("Lactic Studio")
                .font(.lacticDisplay)
            Text("Coach")
                .font(.lacticEyebrow)
                .foregroundStyle(LacticColor.brand)

            if let errorMessage {
                Text(errorMessage)
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.danger)
                    .multilineTextAlignment(.center)
            }

            Button("Continue with Google") { signIn() }
                .lacticButton(isEnabled: !isSigningIn)

            #if DEBUG
                // The picker lives here rather than in Settings because Studio
                // has no signed-in Settings yet, and a build that cannot reach
                // the server it needs is unusable.
                Picker("Server", selection: serverBinding) {
                    ForEach(StudioEnvironment.Server.allCases) { server in
                        Text(server.title).tag(server)
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: LacticSpacing.sm) {
                    TextField("Email", text: $devEmail)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Sign in") { signInWithDevLogin() }
                        .lacticButton(.secondary, isEnabled: !isSigningIn)
                    Text("Uses the API's dev_login route, which does not exist in production.")
                        .font(.lacticCaption)
                        .foregroundStyle(LacticColor.textMuted)
                }
            #endif
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LacticColor.surface)
    }

    #if DEBUG
        private var serverBinding: Binding<StudioEnvironment.Server> {
            Binding(
                get: { environment.server },
                set: { newValue in Task { await environment.applyServer(newValue) } }
            )
        }

        private func signInWithDevLogin() {
            perform { try await environment.session.signInWithDevLogin(email: devEmail) }
        }
    #endif

    private func signIn() {
        perform { try await environment.session.signInWithGoogle() }
    }

    /// A coach signs in with no invitation token: an unrecognised email simply
    /// becomes a coach, which is what open signup means (AGENTS.md §2.3).
    private func perform(_ work: @escaping () async throws -> Void) {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        Task {
            defer { isSigningIn = false }
            do {
                try await work()
            } catch is CancellationError {
                // The user dismissed Google's sheet.
            } catch {
                errorMessage = (error as? APIError)?.message ?? error.localizedDescription
            }
        }
    }
}
