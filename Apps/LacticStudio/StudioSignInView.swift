import LacticKit
import LacticUI
import SwiftUI

/// Coach sign-in, using the same graphite and electric-lime identity as the
/// client app but with a workspace-oriented iPad composition.
struct StudioSignInView: View {
    @Environment(StudioEnvironment.self) private var environment

    @State private var isSigningIn = false
    @State private var errorMessage: String?
    #if DEBUG
        @State private var devEmail = "john@example.com"
    #endif

    var body: some View {
        ScrollView {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: LacticSpacing.xl) {
                    brandPanel
                        .frame(minWidth: 360, maxWidth: .infinity)
                    signInCard
                        .frame(minWidth: 360, maxWidth: 460)
                }

                VStack(spacing: LacticSpacing.xl) {
                    brandPanel
                    signInCard
                }
            }
            .padding(LacticSpacing.xl)
            .frame(maxWidth: 1180)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LacticColor.surface)
    }

    private var brandPanel: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xl) {
            HStack(spacing: LacticSpacing.sm) {
                Image(systemName: "dumbbell.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(LacticColor.heroSurface)
                    .frame(width: 52, height: 52)
                    .background(LacticColor.brand, in: RoundedRectangle(cornerRadius: LacticRadius.control))
                    .accessibilityHidden(true)
                Text("Lactic Studio")
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.textOnHero)
            }

            Spacer(minLength: LacticSpacing.xl)

            VStack(alignment: .leading, spacing: LacticSpacing.md) {
                Text("Coach workspace")
                    .font(.lacticEyebrow)
                    .foregroundStyle(LacticColor.brand)
                    .textCase(.uppercase)
                Text("Build better training, together.")
                    .font(.lacticDisplay)
                    .foregroundStyle(LacticColor.textOnHero)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Manage your clients and keep every training relationship moving from one focused workspace.")
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textOnHero.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: LacticSpacing.xl)

            Label("Secure coach access", systemImage: "lock.shield.fill")
                .font(.lacticCaption.weight(.semibold))
                .foregroundStyle(LacticColor.textOnHero.opacity(0.82))
        }
        .padding(LacticSpacing.xxl)
        .frame(maxWidth: .infinity, minHeight: 520, alignment: .leading)
        .background(
            LacticColor.heroSurface,
            in: RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
        )
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xl) {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                Text("Welcome back")
                    .font(.lacticTitle)
                Text("Sign in to manage your coaching roster.")
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textSecondary)
            }

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

            Button(action: signIn) {
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

            #if DEBUG
                Divider()

                // The picker lives here rather than in Settings because Studio
                // has no signed-in Settings yet, and a build that cannot reach
                // the server it needs is unusable.
                Picker("Server", selection: serverBinding) {
                    ForEach(StudioEnvironment.Server.allCases) { server in
                        Text(server.title).tag(server)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                    TextField("Email", text: $devEmail)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isSigningIn)
                    Button("Sign in") { signInWithDevLogin() }
                        .lacticButton(.secondary, isEnabled: !isSigningIn && !devEmail.isEmpty)
                    Text("Uses the API's dev_login route, which does not exist in production.")
                        .font(.lacticCaption)
                        .foregroundStyle(LacticColor.textMuted)
                }
            #endif
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LacticColor.surfaceElevated,
            in: RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
                .strokeBorder(LacticColor.border, lineWidth: 1)
        }
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
