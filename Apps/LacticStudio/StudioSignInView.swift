import AuthenticationServices
import LacticKit
import LacticUI
import SwiftUI

/// Coach sign-in: the brand mark, a line about what Studio is, and the two
/// sign-in buttons, centred and close together so neither is below the fold.
struct StudioSignInView: View {
    @Environment(StudioEnvironment.self) private var environment

    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        // Centered in the space there is, and scrolling only when there is
        // not enough (a large Dynamic Type size, or a short window).
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: LacticSpacing.xxl) {
                    brand
                    signInControls
                    footer
                }
                .padding(LacticSpacing.xl)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(LacticColor.surface)
    }

    private var brand: some View {
        VStack(spacing: LacticSpacing.lg) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(LacticColor.heroSurface)
                .frame(width: 84, height: 84)
                .background(LacticColor.brand, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityHidden(true)

            VStack(spacing: LacticSpacing.sm) {
                Text("Lactic Studio")
                    .font(.lacticDisplay)
                    .foregroundStyle(LacticColor.textPrimary)
                Text("Build programmes, manage clients, follow their progress.")
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var signInControls: some View {
        VStack(spacing: LacticSpacing.md) {
            if let errorMessage {
                Text(verbatim: errorMessage)
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.danger)
                    .multilineTextAlignment(.leading)
                    .padding(LacticSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LacticColor.dangerSurface,
                        in: RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                    )
            }

            LacticAppleSignInButton(
                isEnabled: !isSigningIn,
                onRequest: AppleSignInProvider.configure,
                onCompletion: signInWithApple
            )

            Button(action: signInWithGoogle) {
                HStack(spacing: LacticSpacing.sm) {
                    if isSigningIn {
                        ProgressView()
                    } else {
                        Image(systemName: "g.circle.fill")
                            .accessibilityHidden(true)
                    }
                    if isSigningIn {
                        Text("Signing in…")
                    } else {
                        Text("Continue with Google")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .lacticButton(isEnabled: !isSigningIn)
        }
    }

    private var footer: some View {
        VStack(spacing: LacticSpacing.lg) {
            Label("Secure coach access", systemImage: "lock.shield.fill")
                .font(.lacticCaption.weight(.semibold))
                .foregroundStyle(LacticColor.textSecondary)

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
            #endif
        }
    }

    #if DEBUG
        private var serverBinding: Binding<StudioEnvironment.Server> {
            Binding(
                get: { environment.server },
                set: { newValue in Task { await environment.applyServer(newValue) } }
            )
        }
    #endif

    private func signInWithGoogle() {
        perform { try await environment.session.signInWithGoogle() }
    }

    private func signInWithApple(_ result: Result<ASAuthorization, any Error>) {
        perform {
            let credential = try AppleSignInProvider.credential(from: result)
            try await environment.session.signInWithApple(credential)
        }
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
            } catch GoogleSignInProvider.Failure.cancelled {
                // The user dismissed Google's sheet.
            } catch AppleSignInProvider.Failure.cancelled {
                // The user dismissed Apple's sheet.
            } catch is AppleSignInProvider.Failure {
                errorMessage = String(localized: "Sign in with Apple didn't finish. Try again.")
            } catch is SessionStore.WrongAppError {
                errorMessage = String(localized: "This is a client account. Sign in to the Lactic app instead.")
            } catch {
                errorMessage = (error as? APIError)?.message ?? error.localizedDescription
            }
        }
    }
}
