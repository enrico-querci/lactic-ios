import AuthenticationServices
import LacticKit
import LacticUI
import SwiftUI

/// Sign in with Apple or Google.
///
/// Both are offered because App Review guideline 4.8 requires a
/// privacy-preserving option wherever a third-party login appears.
struct SignInView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LacticSpacing.xxl) {
                brandHeader

                VStack(spacing: LacticSpacing.md) {
                    LacticAppleSignInButton(
                        isEnabled: !isWorking,
                        onRequest: AppleSignInProvider.configure,
                        onCompletion: signInWithApple
                    )
                    googleButton

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.lacticCaption)
                            .foregroundStyle(LacticColor.danger)
                            .multilineTextAlignment(.center)
                    }

                    #if DEBUG
                        serverPicker
                            .padding(.top, LacticSpacing.lg)
                    #endif
                }
            }
            .frame(maxWidth: 480)
            .padding(LacticSpacing.xl)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LacticColor.surface)
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xl) {
            Image(systemName: "dumbbell.fill")
                .font(.lacticTitle)
                .foregroundStyle(LacticColor.heroSurface)
                .padding(LacticSpacing.lg)
                .background(LacticColor.brand, in: RoundedRectangle(cornerRadius: LacticRadius.control))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                Text("Lactic")
                    .font(.lacticDisplay)
                    .foregroundStyle(LacticColor.textOnHero)
                Text("Follow your programme, log your sets.")
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textOnHero)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LacticSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LacticColor.heroSurface, in: RoundedRectangle(cornerRadius: LacticRadius.card))
    }

    private var googleButton: some View {
        Button(action: signInWithGoogle) {
            HStack(spacing: LacticSpacing.sm) {
                Image(systemName: "g.circle.fill")
                    .accessibilityHidden(true)
                Text("Continue with Google")
            }
        }
        .lacticButton(isEnabled: !isWorking)
    }

    private func signInWithApple(_ result: Result<ASAuthorization, any Error>) {
        isWorking = true
        errorMessage = nil
        Task {
            do {
                let credential = try AppleSignInProvider.credential(from: result)
                try await environment.session.signInWithApple(credential)
            } catch AppleSignInProvider.Failure.cancelled {
                errorMessage = nil
            } catch is AppleSignInProvider.Failure {
                errorMessage = String(localized: "Sign in with Apple didn't finish. Try again.")
            } catch is SessionStore.WrongAppError {
                errorMessage = String(localized: "This is a coach account. Sign in to Lactic Studio instead.")
            } catch let error as APIError {
                errorMessage = error.message
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func signInWithGoogle() {
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await environment.session.signInWithGoogle()
            } catch GoogleSignInProvider.Failure.cancelled {
                // Backing out of the Google sheet is not an error worth
                // reporting; the user knows what they did.
                errorMessage = nil
            } catch is SessionStore.WrongAppError {
                errorMessage = String(localized: "This is a coach account. Sign in to Lactic Studio instead.")
            } catch let error as APIError {
                errorMessage = error.message
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    #if DEBUG
        /// The server switch lives here, not only in Settings.
        ///
        /// Settings is inside the signed-in shell, so a switch that only lived
        /// there was unreachable exactly when it was needed: the app defaults
        /// to the local server, and choosing a different one would have meant
        /// signing in against the local server first.
        private var serverPicker: some View {
            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Picker("Server", selection: serverBinding) {
                    ForEach(AppEnvironment.Server.allCases) { server in
                        Text(server.title).tag(server)
                    }
                }
                .pickerStyle(.segmented)

                Text("Development builds only. Release always uses production.")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textMuted)
            }
        }

        private var serverBinding: Binding<AppEnvironment.Server> {
            Binding(
                get: { environment.server },
                set: { newValue in Task { await environment.applyServer(newValue) } }
            )
        }
    #endif
}
