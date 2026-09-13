import LacticCore
import LacticKit
import LacticUI
import SwiftUI

// This file is a single, tightly scoped feature made of small SwiftUI views.
// Keeping them together makes the roster's loading, empty and action states
// reviewable as one surface.
// swiftlint:disable file_length

/// The iPad-first coach workspace.
///
/// Clients and invitations are peer destinations rather than client-detail
/// navigation. LacticKit does not yet expose a client-detail model, so the UI
/// deliberately stops at the roster instead of deriving progress in a view.
struct StudioClientView: View {
    @Environment(StudioEnvironment.self) private var environment

    let user: User
    @State private var model: ClientListModel?

    var body: some View {
        Group {
            if let model {
                StudioClientNavigation(
                    coachName: user.name,
                    coachEmail: user.email,
                    model: model,
                    signOut: { Task { await environment.session.signOut() } }
                )
            } else {
                LoadingView(String(localized: "Loading your workspace"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LacticColor.surface)
            }
        }
        .task {
            guard model == nil else { return }
            let model = ClientListModel(client: environment.client)
            self.model = model
            await model.load()
        }
    }
}

private enum StudioDestination: Hashable {
    case clients
    case invitations
}

private enum StudioSheet: String, Identifiable {
    case invite

    var id: String {
        rawValue
    }
}

@MainActor
struct StudioClientNavigation: View {
    let coachName: String
    let coachEmail: String
    let model: ClientListModel
    let signOut: () -> Void

    @State private var selection: StudioDestination? = .clients
    @State private var sheet: StudioSheet?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    StudioSidebarRow(
                        title: "Clients",
                        systemImage: "person.2.fill",
                        count: model.clients.count
                    )
                    .tag(StudioDestination.clients)

                    StudioSidebarRow(
                        title: "Invitations",
                        systemImage: "envelope.fill",
                        count: model.pendingInvitations.count
                    )
                    .tag(StudioDestination.invitations)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Lactic Studio")
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 360)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                StudioAccountFooter(
                    name: coachName,
                    email: coachEmail,
                    signOut: signOut
                )
            }
        } detail: {
            detail
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            sheet = .invite
                        } label: {
                            Label("Invite client", systemImage: "person.badge.plus")
                        }
                        // Keep the control visible when the limit is known. The
                        // capacity treatment below explains why it is disabled.
                        // While the plan is unknown, LacticKit remains permissive
                        // and a server 402 gets the purpose-built treatment.
                        .disabled(!model.canInviteClient || model.isSubmitting)
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .invite:
                InviteClientSheet(model: model)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if model.subscription == nil, model.isLoading {
            LoadingView(String(localized: "Loading clients"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LacticColor.surface)
        } else if model.subscription == nil, let failure = model.failure {
            StudioInitialFailureView(failure: failure) {
                Task { await model.load() }
            }
        } else {
            switch selection ?? .clients {
            case .clients:
                StudioClientsDashboard(model: model) {
                    sheet = .invite
                }
            case .invitations:
                StudioInvitationsDashboard(model: model) {
                    sheet = .invite
                }
            }
        }
    }
}

private struct StudioSidebarRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let count: Int

    var body: some View {
        HStack(spacing: LacticSpacing.sm) {
            Label(title, systemImage: systemImage)
            Spacer(minLength: LacticSpacing.sm)
            Text(verbatim: count.formatted())
                .font(.lacticCaption.weight(.semibold).monospacedDigit())
                .foregroundStyle(LacticColor.textSecondary)
                .padding(.horizontal, LacticSpacing.sm)
                .padding(.vertical, LacticSpacing.xs)
                .background(LacticColor.surfacePressed, in: Capsule())
        }
        .frame(minHeight: LacticSize.minimumHitTarget)
    }
}

private struct StudioAccountFooter: View {
    let name: String
    let email: String
    let signOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            HStack(spacing: LacticSpacing.sm) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(LacticColor.accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                    Text(verbatim: name)
                        .font(.lacticHeadline)
                        .lineLimit(1)
                    Text(verbatim: email)
                        .font(.lacticCaption)
                        .foregroundStyle(LacticColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Button(action: signOut) {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .lacticButton(.secondary, size: .small)
        }
        .padding(LacticSpacing.lg)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct StudioClientsDashboard: View {
    let model: ClientListModel
    let invite: () -> Void

    var body: some View {
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
                        columns: [GridItem(.adaptive(minimum: 280), spacing: LacticSpacing.lg)],
                        spacing: LacticSpacing.lg
                    ) {
                        ForEach(model.clients) { client in
                            StudioClientCard(client: client)
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

private struct StudioInvitationsDashboard: View {
    let model: ClientListModel
    let invite: () -> Void

    @State private var invitationToRevoke: ClientInvitation?

    var body: some View {
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
                                revoke: { invitationToRevoke = invitation }
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
        .confirmationDialog(
            "Revoke invitation?",
            isPresented: isConfirmingRevocation,
            titleVisibility: .visible,
            presenting: invitationToRevoke
        ) { invitation in
            Button("Revoke invitation", role: .destructive) {
                Task { await model.revoke(invitationID: invitation.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { invitation in
            Text("The invitation link for \(invitation.email) will stop working.")
        }
    }

    private var isConfirmingRevocation: Binding<Bool> {
        Binding(
            get: { invitationToRevoke != nil },
            set: { isPresented in
                if !isPresented {
                    invitationToRevoke = nil
                }
            }
        )
    }
}

private struct StudioDashboardHeader: View {
    let eyebrow: LocalizedStringKey
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text(eyebrow)
                .font(.lacticEyebrow)
                .foregroundStyle(LacticColor.brand)
                .textCase(.uppercase)
            Text(title)
                .font(.lacticDisplay)
                .foregroundStyle(LacticColor.textOnHero)
            Text(message)
                .font(.lacticBody)
                .foregroundStyle(LacticColor.textOnHero.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LacticColor.heroSurface,
            in: RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
        )
    }
}

private struct StudioOverviewMetrics: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let clientCount: Int
    let invitationCount: Int
    let subscription: CoachSubscription?

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: LacticSpacing.md))
            : AnyLayout(HStackLayout(spacing: LacticSpacing.md))

        layout {
            StudioMetricCard(
                title: "Active clients",
                value: clientCount.formatted(),
                systemImage: "person.2.fill"
            )
            StudioMetricCard(
                title: "Pending invites",
                value: invitationCount.formatted(),
                systemImage: "envelope.fill"
            )
            StudioCapacityMetric(subscription: subscription)
        }
    }
}

private struct StudioMetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: LacticSpacing.md) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(LacticColor.accent)
                .frame(width: LacticSize.minimumHitTarget, height: LacticSize.minimumHitTarget)
                .background(LacticColor.surfacePressed, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text(verbatim: value)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(LacticColor.textPrimary)
                Text(title)
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
            }
        }
        .padding(LacticSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct StudioCapacityMetric: View {
    let subscription: CoachSubscription?

    var body: some View {
        StudioMetricCard(
            title: "Client capacity",
            value: capacity,
            systemImage: "gauge.with.dots.needle.33percent"
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

private struct StudioPlanFullNotice: View {
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

private struct StudioActionFailureNotice: View {
    let failure: CoachActionFailure

    var body: some View {
        HStack(alignment: .top, spacing: LacticSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(LacticColor.danger)
                .frame(width: LacticSize.minimumHitTarget, height: LacticSize.minimumHitTarget)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text(title)
                    .font(.lacticHeadline)
                message
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(LacticSpacing.lg)
        .background(
            LacticColor.dangerSurface,
            in: RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                .strokeBorder(LacticColor.dangerBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch failure {
        case .offline: "wifi.slash"
        case .planIsFull, .rejected: "exclamationmark.triangle.fill"
        }
    }

    private var title: LocalizedStringKey {
        switch failure {
        case .offline: "You're offline"
        case .planIsFull: "Client limit reached"
        case .rejected: "That action was not completed"
        }
    }

    @ViewBuilder
    private var message: some View {
        switch failure {
        case .offline:
            Text("Check your connection and try again.")
        case .planIsFull:
            Text("No client slots are available. Client limits are managed on Lactic Web.")
        case .rejected(let message):
            // The API's wording is deliberately preserved exactly.
            Text(verbatim: message)
        }
    }
}

private struct StudioInitialFailureView: View {
    let failure: CoachActionFailure
    let retry: () -> Void

    var body: some View {
        VStack(spacing: LacticSpacing.lg) {
            StudioActionFailureNotice(failure: failure)
                .frame(maxWidth: 560)
            Button("Try again", action: retry)
                .lacticButton(.secondary)
                .frame(maxWidth: 240)
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LacticColor.surface)
        .navigationTitle("Clients")
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
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    .frame(maxWidth: 140)
                Button("Revoke", action: revoke)
                    .lacticButton(.danger, size: .small, isEnabled: !isSubmitting)
                    .frame(maxWidth: 140)
            }
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

private struct StudioEmptyCard<Action: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        VStack(spacing: LacticSpacing.md) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(LacticColor.textMuted)
                .accessibilityHidden(true)
            Text(title)
                .font(.lacticHeadline)
            Text(message)
                .font(.lacticBody)
                .foregroundStyle(LacticColor.textSecondary)
                .multilineTextAlignment(.center)
            action()
                .padding(.top, LacticSpacing.sm)
        }
        .padding(LacticSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(
            LacticColor.surfaceElevated,
            in: RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
                .strokeBorder(LacticColor.border, lineWidth: 1)
        }
    }
}

private struct InviteClientSheet: View {
    @Environment(\.dismiss) private var dismiss

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
            .task { isEmailFocused = true }
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
