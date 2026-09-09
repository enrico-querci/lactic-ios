import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: HomeModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadableView(model) { snapshot in
                        if snapshot.isEmpty {
                            EmptyStateView(
                                title: String(localized: "Nothing here yet"),
                                message: String(localized: "Once your coach assigns a programme it will show up here."),
                                systemImage: "figure.strengthtraining.traditional"
                            )
                        } else {
                            content(snapshot)
                        }
                    }
                }
            }
            .background(LacticColor.surface)
            .navigationTitle(Text("Lactic"))
        }
        .task {
            let model = model ?? HomeModel(client: environment.client)
            self.model = model
            await model.load()
        }
    }

    private func content(_ snapshot: HomeModel.Snapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LacticSpacing.xl) {
                if let resumable = snapshot.resumable {
                    resumeCard(resumable, snapshot: snapshot)
                }
                if let assignment = snapshot.assignment {
                    currentProgramme(assignment, snapshot: snapshot)
                }
                if !snapshot.recent.isEmpty {
                    recentActivity(snapshot.recent)
                }
            }
            .padding(LacticSpacing.lg)
        }
        .refreshable { await model?.reload() }
    }

    /// Deliberately the loudest thing on the screen. A session left open is the
    /// one action the client is most likely to have come back for.
    private func resumeCard(_ session: WorkoutSession, snapshot: HomeModel.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text("Workout in progress")
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textOnAccent.opacity(0.7))
            Text(workoutName(for: session.workoutID, in: snapshot) ?? String(localized: "Resume"))
                .font(.lacticTitle)
                .foregroundStyle(LacticColor.textOnAccent)
            if let started = session.startedAt {
                Text("Started \(Formatters.dateTime(started, locale: environment.locale))")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textOnAccent.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LacticSpacing.lg)
        .background(LacticColor.accent)
        .clipShape(RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous))
    }

    private func currentProgramme(_ assignment: ProgramAssignment, snapshot: HomeModel.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text("Current programme")
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.textPrimary)

            NavigationLink {
                ProgramDetailView(programID: assignment.program.id)
            } label: {
                VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                    Text(assignment.program.name)
                        .font(.lacticBody.weight(.medium))
                        .foregroundStyle(LacticColor.textPrimary)

                    if let next = snapshot.upNext {
                        Text("Up next: \(next.workout.name) · Week \(next.week.position)")
                            .font(.lacticCaption)
                            .foregroundStyle(LacticColor.textSecondary)
                    } else if snapshot.program != nil {
                        Text("Every workout in this programme is done.")
                            .font(.lacticCaption)
                            .foregroundStyle(LacticColor.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(LacticSpacing.lg)
                .background(LacticColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
                        .strokeBorder(LacticColor.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func recentActivity(_ sessions: [WorkoutSession]) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text("Recent activity")
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.textPrimary)

            ForEach(sessions) { session in
                NavigationLink {
                    SessionDetailView(sessionID: session.id)
                } label: {
                    SessionRow(session: session, locale: environment.locale)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func workoutName(for workoutID: Int, in snapshot: HomeModel.Snapshot) -> String? {
        snapshot.program?.weeks
            .flatMap(\.workouts)
            .first { $0.id == workoutID }?
            .name
    }
}
