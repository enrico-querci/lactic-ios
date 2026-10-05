import LacticKit
import LacticUI
import SwiftUI

/// The coach's own account: who is signed in, signing out, and deleting it.
struct StudioProfileSection: View {
    let name: String
    let email: String
    let signOut: () -> Void
    /// App Review guideline 5.1.1(v): Studio creates accounts, so it must
    /// also delete them from inside the app.
    let deleteAccount: () async throws -> Void

    @State private var isConfirmingDeletion = false
    @State private var isDeleting = false
    @State private var deletionError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xl) {
            LacticProfileHeader(name: name, email: email)

            Button(action: signOut) {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .lacticButton(.secondary, isEnabled: !isDeleting)

            deletionCard
        }
        .confirmationDialog(
            "Delete your coach account?",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) { performDeletion() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                """
                Your programmes, exercises, templates and invitations are deleted, along with \
                the workouts your clients logged against your programmes. Your clients keep \
                their own accounts. This cannot be undone.
                """
            )
        }
        .alert(
            "Account not deleted",
            isPresented: Binding(get: { deletionError != nil }, set: {
                if !$0 {
                    deletionError = nil
                }
            }),
            presenting: deletionError
        ) { _ in
            Button("OK") {}
        } message: { message in
            Text(verbatim: message)
        }
    }

    private var deletionCard: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            Text("Delete account")
                .font(.lacticHeadline)
            Text(
                """
                Your programmes, exercises, templates and invitations are deleted, along with \
                the workouts your clients logged against your programmes. Your clients keep \
                their own accounts. This cannot be undone.
                """
            )
            .font(.lacticBody)
            .foregroundStyle(LacticColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

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

    private func performDeletion() {
        isDeleting = true
        Task {
            defer { isDeleting = false }
            do {
                try await deleteAccount()
            } catch let error as APIError where error.code == "subscription_active" {
                deletionError = String(
                    localized: """
                    Cancel your subscription on the web first. You can delete your account once it \
                    will no longer renew.
                    """
                )
            } catch {
                deletionError = (error as? APIError)?.message ?? error.localizedDescription
            }
        }
    }
}
