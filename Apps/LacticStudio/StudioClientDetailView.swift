import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// One client: who they are, what they are assigned, and every session they
/// have logged against this coach's programmes.
struct StudioClientDetailView: View {
    @Environment(StudioEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var model: ClientDetailModel
    private let client: APIClient
    private let name: String
    private let roster: ClientListModel

    @State private var isAssigning = false
    @State private var isConfirmingRemoval = false

    init(client: APIClient, clientID: Int, name: String, roster: ClientListModel) {
        self.client = client
        self.name = name
        self.roster = roster
        _model = State(initialValue: ClientDetailModel(client: client, clientID: clientID))
    }

    var body: some View {
        Group {
            if model.user == nil, let failure = model.failure {
                StudioInitialFailureView(failure: failure, title: Text(verbatim: title)) {
                    Task { await model.load() }
                }
            } else if let user = model.user {
                content(user)
            } else {
                LoadingView(String(localized: "Loading client"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LacticColor.surface)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Assign a programme", systemImage: "calendar.badge.plus") { isAssigning = true }
                    Button("Remove client", systemImage: "person.badge.minus", role: .destructive) {
                        isConfirmingRemoval = true
                    }
                } label: {
                    Label("Client actions", systemImage: "ellipsis.circle")
                }
                .disabled(model.user == nil)
            }
        }
        .sheet(isPresented: $isAssigning) {
            NewAssignmentSheet(client: client, preselectedClientID: model.clientID) {
                model.assignments.didCreate($0)
            }
        }
        .confirmationDialog(
            "Remove \(model.user?.name ?? name) from your clients?",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove client", role: .destructive, action: remove)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They lose access to your programmes. Their logged history is kept.")
        }
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    private var title: String {
        model.user?.name ?? name
    }

    private func content(_ user: User) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LacticSpacing.xl) {
                LacticProfileHeader(name: user.name, email: user.email)

                let layout = horizontalSizeClass == .compact
                    ? AnyLayout(VStackLayout(spacing: LacticSpacing.sm))
                    : AnyLayout(HStackLayout(spacing: LacticSpacing.md))
                layout {
                    StudioMetricCard(
                        title: "Sessions logged", value: model.sessions.count.formatted(),
                        systemImage: "figure.strengthtraining.traditional", isRow: horizontalSizeClass == .compact
                    )
                    StudioMetricCard(
                        title: "Completed", value: model.completedSessionCount.formatted(),
                        systemImage: "checkmark.seal.fill", isRow: horizontalSizeClass == .compact
                    )
                    StudioMetricCard(
                        title: "Active programmes",
                        value: model.assignments.assignments.filter { $0.status == .active }.count.formatted(),
                        systemImage: "calendar", isRow: horizontalSizeClass == .compact
                    )
                }

                if let failure = roster.failure {
                    StudioActionFailureNotice(failure: failure)
                }

                assignmentsSection
                sessionsSection
            }
            .padding(LacticSpacing.xl)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
        .background(LacticColor.surface)
    }

    private var assignmentsSection: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            HStack {
                Text("Programmes")
                    .font(.lacticTitle)
                Spacer()
                Button("Assign", systemImage: "plus") { isAssigning = true }
                    .lacticButton(.secondary, size: .small)
                    .fixedSize()
            }
            if let failure = model.assignments.failure {
                StudioActionFailureNotice(failure: failure)
            }
            if model.assignments.orderedAssignments.isEmpty {
                Text("No programme assigned yet.")
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textSecondary)
                    .studioCard()
            } else {
                ForEach(model.assignments.orderedAssignments) { assignment in
                    AssignmentCard(assignment: assignment, showsClient: false, model: model.assignments)
                }
            }
        }
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            Text("Workout history")
                .font(.lacticTitle)
            if model.sessions.isEmpty {
                Text("No workout sessions yet.")
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textSecondary)
                    .studioCard()
            } else {
                ForEach(model.sessions) { session in
                    NavigationLink(value: StudioRoute.clientSession(
                        clientID: model.clientID, sessionID: session.id,
                        title: session.workoutName ?? String(localized: "Workout")
                    )) {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func remove() {
        Task {
            if await roster.removeClient(id: model.clientID) {
                dismiss()
            }
        }
    }
}

private struct SessionRow: View {
    @Environment(StudioEnvironment.self) private var environment
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: LacticSpacing.md) {
            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text(verbatim: session.workoutName ?? String(localized: "Workout"))
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.textPrimary)
                if let startedAt = session.startedAt {
                    Text(verbatim: Formatters.dateTime(startedAt, locale: environment.locale))
                        .font(.lacticCaption)
                        .foregroundStyle(LacticColor.textSecondary)
                }
                if let notes = session.notes, !notes.isEmpty {
                    Text(verbatim: notes)
                        .font(.lacticCaption)
                        .italic()
                        .foregroundStyle(LacticColor.textSecondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let startedAt = session.startedAt, let completedAt = session.completedAt {
                Text(verbatim: Formatters.duration(from: startedAt, to: completedAt))
                    .font(.lacticNumeric)
                    .foregroundStyle(LacticColor.textSecondary)
            } else {
                StatusBadge(String(localized: "In progress"), tone: .caution)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LacticColor.textMuted)
                .accessibilityHidden(true)
        }
        .studioCard()
        .accessibilityElement(children: .combine)
    }
}

/// One logged session: every exercise and every set, as the client did them.
struct StudioClientSessionView: View {
    @Environment(StudioEnvironment.self) private var environment
    @State private var model: ClientSessionModel
    private let title: String

    init(client: APIClient, clientID: Int, sessionID: Int, title: String) {
        self.title = title
        _model = State(initialValue: ClientSessionModel(client: client, clientID: clientID, sessionID: sessionID))
    }

    var body: some View {
        Group {
            if let summary = model.summary {
                content(summary)
            } else if let failure = model.failure {
                StudioInitialFailureView(failure: failure, title: Text(verbatim: title)) {
                    Task { await model.load() }
                }
            } else {
                LoadingView(String(localized: "Loading session"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LacticColor.surface)
            }
        }
        .navigationTitle(model.summary?.workoutName ?? title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    private func content(_ summary: SessionSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LacticSpacing.xl) {
                overview(summary)
                ForEach(summary.orderedExerciseLogs) { log in
                    exerciseCard(log, reference: summary.reference(for: log))
                }
                if summary.session.exerciseLogs.isEmpty {
                    Text("No sets were logged in this session.")
                        .font(.lacticBody)
                        .foregroundStyle(LacticColor.textSecondary)
                        .studioCard()
                }
            }
            .padding(LacticSpacing.xl)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .background(LacticColor.surface)
    }

    private func overview(_ summary: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            if let startedAt = summary.session.startedAt {
                Text(verbatim: Formatters.dateTime(startedAt, locale: environment.locale))
                    .font(.lacticEyebrow)
                    .foregroundStyle(LacticColor.brand)
                    .textCase(.uppercase)
            }
            Text(verbatim: summary.workoutName ?? String(localized: "Workout"))
                .font(.lacticDisplay)
                .foregroundStyle(LacticColor.textOnHero)
            HStack(spacing: LacticSpacing.xl) {
                stat(value: summary.totalSetCount.formatted(), label: "Sets")
                stat(value: summary.totalReps.formatted(), label: "Reps")
                stat(
                    value: "\(Formatters.weight(summary.totalVolumeKg, locale: environment.locale)) kg",
                    label: "Volume"
                )
                if let start = summary.session.startedAt, let end = summary.session.completedAt {
                    stat(value: Formatters.duration(from: start, to: end), label: "Duration")
                }
            }
            if let notes = summary.session.notes, !notes.isEmpty {
                Text(verbatim: notes)
                    .font(.lacticBody)
                    .italic()
                    .foregroundStyle(LacticColor.textOnHero.opacity(0.8))
            }
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LacticColor.heroSurface, in: RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous))
    }

    private func stat(value: String, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xs) {
            Text(verbatim: value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(LacticColor.textOnHero)
            Text(label)
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textOnHero.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
    }

    private func exerciseCard(_ log: ExerciseLogDetail, reference: SessionSummary.ExerciseReference?) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            HStack(spacing: LacticSpacing.sm) {
                if let position = reference?.position {
                    PositionBadge(position)
                }
                Text(verbatim: reference?.name ?? String(localized: "Exercise"))
                    .font(.lacticHeadline)
            }
            ForEach(Array(log.orderedSets.enumerated()), id: \.element.id) { index, set in
                HStack {
                    Text("Set \(index + 1)")
                        .foregroundStyle(LacticColor.textSecondary)
                    Spacer()
                    Text(verbatim: "\(Formatters.weight(set.weightKg, locale: environment.locale)) kg × \(set.reps)")
                        .font(.lacticNumeric)
                }
                .font(.lacticBody)
            }
            if let notes = log.notes, !notes.isEmpty {
                Text(verbatim: notes)
                    .font(.lacticCaption)
                    .italic()
                    .foregroundStyle(LacticColor.textSecondary)
            }
        }
        .studioCard()
    }
}
