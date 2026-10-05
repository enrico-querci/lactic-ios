import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// Account: who is signed in, the plan and how much of it is used, and the
/// two account actions — one narrow column of cards, centred, rather than a
/// hero per topic.
///
/// The plan is read-only on purpose. Selling or linking to a subscription from
/// inside the app is an unresolved App Review question (AGENTS.md §8,
/// docs/studio-ui-brief.md §6), and getting it wrong could keep Studio off the
/// store. Plans are bought on the web; this screen only reports.
struct StudioAccountView: View {
    @Environment(StudioEnvironment.self) private var environment

    let roster: ClientListModel
    let name: String
    let email: String
    let signOut: () -> Void
    /// App Review guideline 5.1.1(v): Studio creates accounts, so it must also
    /// delete them from inside the app.
    let deleteAccount: () async throws -> Void

    @State private var isConfirmingDeletion = false
    @State private var isDeleting = false
    @State private var deletionError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LacticSpacing.lg) {
                    profileCard
                    planCard
                    actionsCard
                }
                .padding(LacticSpacing.xl)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(LacticColor.surface)
            .navigationTitle("Account")
            .refreshable { await roster.load() }
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

    // MARK: - Profile

    private var profileCard: some View {
        HStack(spacing: LacticSpacing.lg) {
            Text(verbatim: initials)
                .font(.title3.weight(.bold))
                .foregroundStyle(LacticColor.heroSurface)
                .frame(width: 56, height: 56)
                .background(LacticColor.brand, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text(verbatim: name)
                    .font(.lacticTitle)
                    .foregroundStyle(LacticColor.textPrimary)
                Text(verbatim: email)
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .studioCard(radius: LacticRadius.card)
        .accessibilityElement(children: .combine)
    }

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    // MARK: - Plan

    @ViewBuilder
    private var planCard: some View {
        if let subscription = roster.subscription {
            VStack(alignment: .leading, spacing: LacticSpacing.lg) {
                planHeader(subscription)

                if subscription.billingIssue {
                    Label {
                        Text(
                            "There's a problem with your latest payment. Update your payment method to keep your plan."
                        )
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(LacticColor.warning)
                    }
                    .font(.lacticBody)
                    .padding(LacticSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LacticColor.warningSurface,
                        in: RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                    )
                }

                Divider()
                usage(subscription)

                Text(
                    """
                    Your plan sets how many clients you can have, counting pending invitations. \
                    If it lapses, your existing clients keep everything; only new invitations wait.
                    """
                )
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .studioCard(radius: LacticRadius.card)
        } else if let failure = roster.failure {
            VStack(spacing: LacticSpacing.lg) {
                StudioActionFailureNotice(failure: failure)
                Button("Try again") { Task { await roster.load() } }
                    .lacticButton(.secondary)
                    .frame(maxWidth: 240)
            }
        } else {
            LoadingView(String(localized: "Loading your plan"))
                .frame(maxWidth: .infinity, minHeight: 120)
        }
    }

    private func planHeader(_ subscription: CoachSubscription) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text("Current plan")
                    .font(.lacticEyebrow)
                    .foregroundStyle(LacticColor.textSecondary)
                    .textCase(.uppercase)
                Text(verbatim: subscription.plan.label)
                    .font(.lacticTitle)
                    .foregroundStyle(LacticColor.textPrimary)
            }
            Spacer()
            if let expiresAt = subscription.expiresAt {
                let date = Formatters.date(expiresAt, locale: environment.locale)
                Group {
                    if subscription.autoRenew == false {
                        Text("Ends on \(date)")
                    } else {
                        Text("Renews on \(date)")
                    }
                }
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textSecondary)
                .multilineTextAlignment(.trailing)
            }
        }
    }

    private func usage(_ subscription: CoachSubscription) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text("Client slots")
                .font(.lacticEyebrow)
                .foregroundStyle(LacticColor.textSecondary)
                .textCase(.uppercase)
            if let limit = subscription.clientLimit {
                Text("\(subscription.clientSlotsUsed) of \(limit) clients")
                    .font(.title2.weight(.bold).monospacedDigit())
                ProgressView(value: Double(min(subscription.clientSlotsUsed, limit)), total: Double(max(limit, 1)))
                    .tint(subscription.canInviteClient ? LacticColor.accent : LacticColor.warning)
                    .accessibilityHidden(true)
            } else {
                Text("\(subscription.clientSlotsUsed) clients · unlimited")
                    .font(.title2.weight(.bold).monospacedDigit())
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private var actionsCard: some View {
        VStack(spacing: 0) {
            Button(action: signOut) {
                actionRow("Sign out", systemImage: "rectangle.portrait.and.arrow.right", tint: LacticColor.textPrimary)
            }
            Divider()
            Button {
                isConfirmingDeletion = true
            } label: {
                if isDeleting {
                    ProgressView().frame(maxWidth: .infinity, minHeight: LacticSize.minimumHitTarget)
                } else {
                    actionRow("Delete account", systemImage: "trash", tint: LacticColor.danger)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDeleting)
        .studioCard(radius: LacticRadius.card, padding: 0)
    }

    private func actionRow(_ title: LocalizedStringKey, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.lacticBody.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, LacticSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
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
