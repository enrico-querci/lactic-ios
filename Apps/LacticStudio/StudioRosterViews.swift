import LacticCore
import LacticKit
import LacticUI
import SwiftUI

// The roster: clients and pending invitations in one list, because the two
// share their plan, failure and empty states — and because an invitation is
// just a client who has not arrived yet.
// swiftlint:disable file_length

/// The Clients tab's first column: how full the plan is, the coach's clients,
/// and the invitations still waiting. Selecting a client opens them beside it.
struct StudioRosterList: View {
    let model: ClientListModel
    @Binding var selection: Int?

    @State private var isInviting = false
    @State private var pendingRevocation: ClientInvitation?

    var body: some View {
        StudioRosterGate(model: model, title: Text("Clients")) {
            list
        }
        .inviteClientControls(model: model, isInviting: $isInviting)
        .confirmationDialog(
            "Revoke invitation?",
            isPresented: Binding(get: { pendingRevocation != nil }, set: {
                if !$0 {
                    pendingRevocation = nil
                }
            }),
            titleVisibility: .visible,
            presenting: pendingRevocation
        ) { invitation in
            Button("Revoke invitation", role: .destructive) {
                Task { await model.revoke(invitationID: invitation.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { invitation in
            Text("The invitation link for \(invitation.email) will stop working.")
        }
    }

    private var list: some View {
        List(selection: $selection) {
            Section {
                StudioCapacityRow(subscription: model.subscription)
                    .studioPlainRow()
                if model.failure == .planIsFull || model.canInviteClient == false {
                    StudioPlanFullNotice(subscription: model.subscription)
                        .studioPlainRow()
                } else if let failure = model.failure {
                    StudioActionFailureNotice(failure: failure)
                        .studioPlainRow()
                }
            }

            Section {
                if model.clients.isEmpty {
                    StudioEmptyCard(
                        title: "No clients yet",
                        message: "Invite your first client to start building your roster.",
                        systemImage: "person.2"
                    ) {
                        Button("Invite client") { isInviting = true }
                            .lacticButton(isEnabled: model.canInviteClient)
                            .frame(maxWidth: 280)
                    }
                    .studioPlainRow()
                } else {
                    ForEach(model.clients) { client in
                        StudioClientRow(client: client)
                            .tag(client.id)
                            .studioListRow(isSelected: selection == client.id)
                    }
                }
            } header: {
                StudioSectionHeader("Clients")
            }

            if !model.pendingInvitations.isEmpty {
                Section {
                    ForEach(model.pendingInvitations) { invitation in
                        StudioInvitationRow(
                            invitation: invitation,
                            isSubmitting: model.isSubmitting,
                            resend: { Task { await model.resend(invitationID: invitation.id) } },
                            revoke: { pendingRevocation = invitation }
                        )
                        .selectionDisabled()
                        .studioListRow()
                    }
                } header: {
                    StudioSectionHeader("Pending invitations")
                }
            }
        }
        .studioListColumn()
        .navigationTitle("Clients")
        .refreshable { await model.load() }
    }
}

/// Plan usage at a glance, where the coach decides whether to invite.
private struct StudioCapacityRow: View {
    let subscription: CoachSubscription?

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Label {
                Text(verbatim: summary)
                    .font(.lacticHeadline.monospacedDigit())
            } icon: {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .foregroundStyle(LacticColor.accent)
            }
            if let subscription, let limit = subscription.clientLimit {
                ProgressView(value: Double(min(subscription.clientSlotsUsed, limit)), total: Double(max(limit, 1)))
                    .tint(subscription.canInviteClient ? LacticColor.accent : LacticColor.warning)
                    .accessibilityHidden(true)
            }
        }
        .studioCard()
        .accessibilityElement(children: .combine)
    }

    private var summary: String {
        guard let subscription else { return "—" }
        guard let limit = subscription.clientLimit else {
            return String(localized: "\(subscription.clientSlotsUsed) clients · unlimited")
        }
        return String(localized: "\(subscription.clientSlotsUsed) of \(limit) clients")
    }
}

struct StudioPlanFullNotice: View {
    let subscription: CoachSubscription?

    var body: some View {
        HStack(alignment: .top, spacing: LacticSpacing.md) {
            Image(systemName: "person.2.slash.fill")
                .font(.title2)
                .foregroundStyle(LacticColor.warning)
                .frame(width: LacticSize.minimumHitTarget, height: LacticSize.minimumHitTarget)
                .background(LacticColor.warningSurface, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Client limit reached")
                        .font(.lacticHeadline)
                    Spacer()
                    if let subscription, let limit = subscription.clientLimit {
                        Text(verbatim: "\(subscription.clientSlotsUsed.formatted()) / \(limit.formatted())")
                            .font(.lacticNumeric.weight(.semibold))
                            .foregroundStyle(LacticColor.warning)
                    }
                }
                Text("No client slots are available. Client limits are managed on Lactic Web.")
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LacticSpacing.lg)
        .background(
            LacticColor.warningSurface,
            in: RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                .strokeBorder(LacticColor.warning.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StudioClientRow: View {
    let client: User

    var body: some View {
        HStack(spacing: LacticSpacing.md) {
            Image(systemName: "person.crop.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(LacticColor.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text(verbatim: client.name)
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.textPrimary)
                Text(verbatim: client.email)
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StudioInvitationRow: View {
    @Environment(StudioEnvironment.self) private var environment

    let invitation: ClientInvitation
    let isSubmitting: Bool
    let resend: () -> Void
    let revoke: () -> Void

    var body: some View {
        HStack(spacing: LacticSpacing.md) {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                Text(verbatim: invitation.email)
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: LacticSpacing.sm) {
                    StatusBadge(String(localized: "Pending"), tone: .caution)
                    Text("Expires \(Formatters.date(invitation.expiresAt, locale: environment.locale))")
                        .font(.lacticCaption)
                        .foregroundStyle(LacticColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                actions
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(width: LacticSize.minimumHitTarget, height: LacticSize.minimumHitTarget)
                    .contentShape(Rectangle())
            }
            .disabled(isSubmitting)
            .accessibilityLabel(Text("Invitation actions"))
        }
        .swipeActions(edge: .trailing) {
            Button("Revoke", systemImage: "xmark.circle", role: .destructive, action: revoke)
            Button("Resend", systemImage: "arrow.clockwise", action: resend)
                .tint(LacticColor.accent)
        }
        .contextMenu { actions }
    }

    @ViewBuilder
    private var actions: some View {
        Button("Resend", systemImage: "arrow.clockwise", action: resend)
        Button("Revoke", systemImage: "xmark.circle", role: .destructive, action: revoke)
    }
}

struct InviteClientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: ClientListModel
    @State private var email = ""
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LacticSpacing.xl) {
                    VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                        Text("Invite a client")
                            .font(.lacticTitle)
                        Text(
                            """
                            Send an invitation by email. They’ll join your roster after signing in \
                            with the same address.
                            """
                        )
                        .font(.lacticBody)
                        .foregroundStyle(LacticColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                        Text("Email address")
                            .font(.lacticEyebrow)
                            .foregroundStyle(LacticColor.textSecondary)
                        TextField("name@example.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isEmailFocused)
                            .submitLabel(.send)
                            .onSubmit(submit)
                            .padding(LacticSpacing.md)
                            .background(
                                LacticColor.surfaceElevated,
                                in: RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                                    .strokeBorder(LacticColor.borderStrong, lineWidth: 1)
                            }
                    }

                    if model.failure == .planIsFull {
                        StudioPlanFullNotice(subscription: model.subscription)
                    } else if let failure = model.failure {
                        StudioActionFailureNotice(failure: failure)
                    }

                    Button(action: submit) {
                        if model.isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Send invitation")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .lacticButton(isEnabled: canSubmit)
                }
                .padding(LacticSpacing.xl)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(LacticColor.surface)
            .navigationTitle("New invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if !dynamicTypeSize.isAccessibilitySize {
                    isEmailFocused = true
                }
            }
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.isSubmitting
            && model.canInviteClient
    }

    private func submit() {
        guard canSubmit else { return }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            if await model.invite(email: email) {
                dismiss()
            }
        }
    }
}

/// The roster's first load: a spinner until something arrives, and a retry if
/// nothing does. Once the roster has loaded, later failures are shown inline
/// by the screen instead of replacing it.
struct StudioRosterGate<Content: View>: View {
    let model: ClientListModel
    let title: Text
    @ViewBuilder let content: () -> Content

    var body: some View {
        if model.subscription == nil, model.isLoading {
            LoadingView(String(localized: "Loading clients"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LacticColor.surface)
                .navigationTitle(title)
        } else if model.subscription == nil, let failure = model.failure {
            StudioInitialFailureView(failure: failure, title: title) {
                Task { await model.load() }
            }
        } else {
            content()
        }
    }
}

extension View {
    /// The Invite client toolbar button and the sheet it opens.
    func inviteClientControls(model: ClientListModel, isInviting: Binding<Bool>) -> some View {
        modifier(InviteClientControls(model: model, isInviting: isInviting))
    }
}

private struct InviteClientControls: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: ClientListModel
    @Binding var isInviting: Bool

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isInviting = true
                    } label: {
                        Label("Invite client", systemImage: "person.badge.plus")
                    }
                    // Keep the control visible when the limit is known. The
                    // capacity treatment explains why it is disabled. While the
                    // plan is unknown, LacticKit remains permissive and a server
                    // 402 gets the purpose-built treatment.
                    .disabled(!model.canInviteClient || model.isSubmitting)
                }
            }
            .sheet(isPresented: $isInviting) {
                InviteClientSheet(model: model)
                    .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
            }
    }
}
