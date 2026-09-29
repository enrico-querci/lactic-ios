import LacticCore
import LacticKit
import LacticUI
import SwiftUI

// The roster: clients and pending invitations. One file because the two
// screens share their plan, failure and empty states.
// swiftlint:disable file_length

struct StudioClientsDashboard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: ClientListModel
    @State private var isInviting = false

    var body: some View {
        StudioRosterGate(model: model, title: Text("Clients")) {
            content
        }
        .inviteClientControls(model: model, isInviting: $isInviting)
    }

    private func invite() {
        isInviting = true
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LacticSpacing.xl) {
                StudioDashboardHeader(
                    eyebrow: "Client roster",
                    title: "Your clients",
                    message: "Keep clients and pending invitations organised in one place."
                )

                StudioOverviewMetrics(
                    clientCount: model.clients.count,
                    invitationCount: model.pendingInvitations.count,
                    subscription: model.subscription
                )

                if model.failure == .planIsFull || model.canInviteClient == false {
                    StudioPlanFullNotice(subscription: model.subscription)
                } else if let failure = model.failure {
                    StudioActionFailureNotice(failure: failure)
                }

                if model.clients.isEmpty {
                    StudioEmptyCard(
                        title: "No clients yet",
                        message: "Invite your first client to start building your roster.",
                        systemImage: "person.2"
                    ) {
                        Button("Invite client", action: invite)
                            .lacticButton()
                            .frame(maxWidth: 280)
                    }
                } else {
                    LazyVGrid(
                        columns: dynamicTypeSize.isAccessibilitySize
                            ? [GridItem(.flexible())]
                            : [GridItem(.adaptive(minimum: 280), spacing: LacticSpacing.lg)],
                        spacing: LacticSpacing.lg
                    ) {
                        ForEach(model.clients) { client in
                            NavigationLink(value: StudioRoute.client(id: client.id, name: client.name)) {
                                StudioClientCard(client: client)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(LacticSpacing.xl)
            .frame(maxWidth: 1080)
            .frame(maxWidth: .infinity)
        }
        .background(LacticColor.surface)
        .navigationTitle("Clients")
        .refreshable { await model.load() }
    }
}

struct StudioInvitationsDashboard: View {
    let model: ClientListModel
    @State private var isInviting = false

    var body: some View {
        StudioRosterGate(model: model, title: Text("Invitations")) {
            content
        }
        .inviteClientControls(model: model, isInviting: $isInviting)
    }

    private func invite() {
        isInviting = true
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LacticSpacing.xl) {
                StudioDashboardHeader(
                    eyebrow: "Client roster",
                    title: "Pending invitations",
                    message: "Follow up with people who have not joined your roster yet."
                )

                if model.failure == .planIsFull || model.canInviteClient == false {
                    StudioPlanFullNotice(subscription: model.subscription)
                } else if let failure = model.failure {
                    StudioActionFailureNotice(failure: failure)
                }

                if model.pendingInvitations.isEmpty {
                    StudioEmptyCard(
                        title: "No pending invitations",
                        message: "Invitations waiting for a response will appear here.",
                        systemImage: "envelope.open"
                    ) {
                        Button("Invite client", action: invite)
                            .lacticButton(isEnabled: model.canInviteClient)
                            .frame(maxWidth: 280)
                    }
                } else {
                    VStack(spacing: LacticSpacing.md) {
                        ForEach(model.pendingInvitations) { invitation in
                            StudioInvitationRow(
                                invitation: invitation,
                                isSubmitting: model.isSubmitting,
                                resend: {
                                    Task { await model.resend(invitationID: invitation.id) }
                                },
                                revoke: {
                                    Task { await model.revoke(invitationID: invitation.id) }
                                }
                            )
                        }
                    }
                }
            }
            .padding(LacticSpacing.xl)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
        .background(LacticColor.surface)
        .navigationTitle("Invitations")
        .refreshable { await model.load() }
    }
}

private struct StudioOverviewMetrics: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let clientCount: Int
    let invitationCount: Int
    let subscription: CoachSubscription?

    /// Three cards side by side only have room on a regular-width screen. On
    /// an iPhone they squeezed their labels down to a letter per line, so a
    /// compact width stacks them as full-width rows instead.
    private var isStacked: Bool {
        horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        let layout = isStacked
            ? AnyLayout(VStackLayout(spacing: LacticSpacing.sm))
            : AnyLayout(HStackLayout(spacing: LacticSpacing.md))

        layout {
            StudioMetricCard(
                title: "Active clients",
                value: clientCount.formatted(),
                systemImage: "person.2.fill",
                isRow: isStacked
            )
            StudioMetricCard(
                title: "Pending invites",
                value: invitationCount.formatted(),
                systemImage: "envelope.fill",
                isRow: isStacked
            )
            StudioCapacityMetric(subscription: subscription, isRow: isStacked)
        }
    }
}

private struct StudioCapacityMetric: View {
    let subscription: CoachSubscription?
    var isRow = false

    var body: some View {
        StudioMetricCard(
            title: "Client capacity",
            value: capacity,
            systemImage: "gauge.with.dots.needle.33percent",
            isRow: isRow
        )
    }

    private var capacity: String {
        guard let subscription else { return "—" }
        guard let limit = subscription.clientLimit else {
            return String(localized: "Unlimited")
        }
        return "\(subscription.clientSlotsUsed.formatted()) / \(limit.formatted())"
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

private struct StudioClientCard: View {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LacticColor.textMuted)
                .accessibilityHidden(true)
        }
        .padding(LacticSpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(
            LacticColor.surfaceElevated,
            in: RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                .strokeBorder(LacticColor.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StudioInvitationRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(StudioEnvironment.self) private var environment

    let invitation: ClientInvitation
    let isSubmitting: Bool
    let resend: () -> Void
    let revoke: () -> Void
    @State private var isConfirmingRevocation = false

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: LacticSpacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: LacticSpacing.lg))

        layout {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                HStack(spacing: LacticSpacing.sm) {
                    Text(verbatim: invitation.email)
                        .font(.lacticHeadline)
                    StatusBadge(String(localized: "Pending"), tone: .caution)
                }
                LabeledContent {
                    Text(verbatim: Formatters.date(invitation.expiresAt, locale: environment.locale))
                } label: {
                    Text("Expires")
                }
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: LacticSpacing.sm) {
                Button("Resend", action: resend)
                    .lacticButton(.secondary, size: .small, isEnabled: !isSubmitting)
                    .lineLimit(1)
                Button("Revoke") {
                    isConfirmingRevocation = true
                }
                .lacticButton(.danger, size: .small, isEnabled: !isSubmitting)
                .lineLimit(1)
                .confirmationDialog(
                    "Revoke invitation?",
                    isPresented: $isConfirmingRevocation,
                    titleVisibility: .visible
                ) {
                    Button("Revoke invitation", role: .destructive, action: revoke)
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The invitation link for \(invitation.email) will stop working.")
                }
            }
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 300)
        }
        .padding(LacticSpacing.lg)
        .background(
            LacticColor.surfaceElevated,
            in: RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                .strokeBorder(LacticColor.border, lineWidth: 1)
        }
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
