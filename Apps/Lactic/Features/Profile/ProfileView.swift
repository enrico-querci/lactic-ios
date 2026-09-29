import LacticKit
import LacticUI
import SwiftUI

/// The client's own account: who is signed in, signing out, and deleting it.
///
/// Its own tab rather than rows in Settings: Settings is about how the app
/// behaves, this is about the account itself.
struct ProfileView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var isConfirmingDeletion = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LacticSpacing.xl) {
                    if let user = environment.session.phase.user {
                        LacticProfileHeader(name: user.name, email: user.email)
                    }

                    Button {
                        Task { await environment.session.signOut() }
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .lacticButton(.secondary, isEnabled: !isDeleting)

                    deletionCard
                }
                .padding(LacticSpacing.lg)
            }
            .background(LacticColor.surface)
            .navigationTitle(Text("Profile"))
            .confirmationDialog(
                "Delete your account?",
                isPresented: $isConfirmingDeletion,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your assignments and logged workouts are deleted too. This cannot be undone.")
            }
        }
    }

    private var deletionCard: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            Text("Delete account")
                .font(.lacticHeadline)
            Text(
                """
                Permanently removes your account, your programme assignments \
                and every workout you have logged. This cannot be undone.
                """
            )
            .font(.lacticBody)
            .foregroundStyle(LacticColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            if let errorMessage {
                Text(verbatim: errorMessage)
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.danger)
            }

            Button {
                isConfirmingDeletion = true
            } label: {
                if isDeleting {
                    ProgressView()
                } else {
                    Text("Delete account")
                }
            }
            .lacticButton(.danger, isEnabled: !isDeleting)
        }
        .padding(LacticSpacing.lg)
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

    private func deleteAccount() {
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                try await environment.client.sendIgnoringResponse(ClientAPI.deleteAccount)
                // The account is gone, so there is no session left to revoke —
                // clear locally rather than calling DELETE /auth.
                await environment.session.clearSession()
            } catch {
                errorMessage = (error as? APIError)?.message ?? error.localizedDescription
            }
            isDeleting = false
        }
    }
}
