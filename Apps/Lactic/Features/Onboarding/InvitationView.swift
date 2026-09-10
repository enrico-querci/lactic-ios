import LacticKit
import LacticUI
import SwiftUI

/// Accepting a coach's invitation.
///
/// **Unstyled on purpose.** Every decision here is the flow's, not the
/// design's: which of `InvitationStep`'s four branches applies, and what each
/// one offers. The visual pass for onboarding and account states is still to
/// come, so this uses plain stacks and existing tokens rather than pre-empting
/// it — the shape to keep is the branch structure, not the layout.
///
/// The logic itself lives in `LacticKit`: `InvitationFlow` decides the step and
/// `InvitationModel` performs the actions.
struct InvitationView: View {
    @Environment(AppEnvironment.self) private var environment

    let token: String

    @State private var model: InvitationModel?

    var body: some View {
        Group {
            // The `else` matters: a `Group` whose only branch is `if let` with
            // no alternative resolves to nothing, SwiftUI never materialises
            // it, and the `.task` that creates the model never runs — a blank
            // screen that no unit test can see.
            if let model {
                content(for: model)
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LacticColor.surface)
        .task {
            let created = model ?? InvitationModel(
                token: token, client: environment.client, session: environment.session
            )
            model = created
            await created.load()
        }
    }

    private func content(for model: InvitationModel) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.lg) {
            Text("Invitation")
                .font(.lacticTitle)

            if let invitation = model.invitation {
                VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                    Text("From \(invitation.coachName)")
                    Text("For \(invitation.email)")
                        .foregroundStyle(LacticColor.textSecondary)
                }
                .font(.lacticBody)
            }

            if let failure = model.failure {
                Text(message(for: failure))
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.danger)
            }

            if model.isLoading {
                ProgressView()
            } else if let step = model.step {
                actions(for: step, model: model)
            }

            Button("Not now") { environment.dismissInvitation() }
                .lacticButton(.secondary)
        }
        .padding(LacticSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func actions(for step: InvitationStep, model: InvitationModel) -> some View {
        switch step {
        case .unavailable:
            Text("This invitation is no longer available. Ask your coach to send a new one.")
                .font(.lacticBody)
                .foregroundStyle(LacticColor.textSecondary)

        case .signInRequired:
            Button("Continue with Google") {
                Task {
                    if await model.signInWithGoogle() {
                        environment.dismissInvitation()
                    }
                }
            }
            .lacticButton(isEnabled: !model.isSubmitting)

        case .readyToAccept:
            Button("Accept invitation") {
                Task {
                    if await model.accept() {
                        environment.dismissInvitation()
                    }
                }
            }
            .lacticButton(isEnabled: !model.isSubmitting)

        case .blocked(let reason, let signedInAs, let invited):
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                switch reason {
                case .differentEmail:
                    Text("You are signed in as \(signedInAs), but this invitation is for \(invited).")
                case .coachAccount:
                    Text("You are signed in as a coach. A coach account cannot accept a client invitation.")
                }
                Button("Sign out") { Task { await model.signOut() } }
                    .lacticButton(.secondary)
            }
            .font(.lacticBody)
            .foregroundStyle(LacticColor.textSecondary)
        }
    }

    /// `InvitationFailure` is a reason rather than a sentence, so the copy —
    /// and its translation — belongs here. `.server` is the exception: that
    /// text is written by the API per case, and is what the web shows too.
    private func message(for failure: InvitationFailure) -> String {
        switch failure {
        case .notFound: String(localized: "We could not find that invitation. Check the link or code.")
        case .offline: String(localized: "You appear to be offline.")
        case .server(let message): message
        }
    }
}
