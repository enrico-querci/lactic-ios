import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct HistoryView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: HistoryModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadableView(model) { sessions in
                        if sessions.isEmpty {
                            EmptyStateView(
                                title: String(localized: "No workouts logged yet"),
                                message: String(localized: "Sessions you complete will appear here."),
                                systemImage: "clock.arrow.circlepath"
                            )
                        } else {
                            ScrollView {
                                LazyVStack(spacing: LacticSpacing.sm) {
                                    ForEach(sessions) { session in
                                        NavigationLink {
                                            SessionDetailView(sessionID: session.id)
                                        } label: {
                                            SessionRow(session: session, locale: environment.locale)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(LacticSpacing.lg)
                            }
                            .refreshable { await model.reload() }
                        }
                    }
                }
            }
            .background(LacticColor.surface)
            .navigationTitle(Text("History"))
        }
        .task {
            let model = model ?? HistoryModel(client: environment.client)
            self.model = model
            await model.load()
        }
    }
}

struct SessionRow: View {
    let session: WorkoutSession
    let locale: AppLocale

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: LacticSpacing.sm) {
            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text(startedAt)
                    .font(.lacticBody.weight(.medium))
                    .foregroundStyle(LacticColor.textPrimary)
                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.lacticCaption)
                        .foregroundStyle(LacticColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: LacticSpacing.sm)

            if let duration = ClientFormat.duration(of: session) {
                Text(duration)
                    .font(.lacticCaption.monospacedDigit())
                    .foregroundStyle(LacticColor.textSecondary)
            } else {
                StatusBadge(String(localized: "In progress"), tone: .informative)
            }
        }
        .padding(LacticSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LacticColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
                .strokeBorder(LacticColor.border, lineWidth: 1)
        }
    }

    private var startedAt: String {
        guard let started = session.startedAt else { return String(localized: "Not started") }
        return Formatters.dateTime(started, locale: locale)
    }
}

struct SessionDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    let sessionID: Int

    @State private var model: SessionDetailModel?

    var body: some View {
        Group {
            if let model {
                LoadableView(model) { detail in
                    content(detail)
                }
            } else {
                LoadingView()
            }
        }
        .background(LacticColor.surface)
        .navigationTitle(Text("Session"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let model = model ?? SessionDetailModel(client: environment.client, sessionID: sessionID)
            self.model = model
            await model.load()
        }
    }

    private func content(_ detail: SessionDetailModel.Detail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LacticSpacing.lg) {
                header(detail.session)

                ForEach(detail.session.exerciseLogs) { log in
                    exerciseLog(log, detail: detail)
                }
            }
            .padding(LacticSpacing.lg)
        }
    }

    private func header(_ session: WorkoutSessionDetail) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xs) {
            if let started = session.startedAt {
                Text(Formatters.dateTime(started, locale: environment.locale))
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.textPrimary)
            }
            if let started = session.startedAt, let completed = session.completedAt {
                Text("Duration \(Formatters.duration(from: started, to: completed))")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
            }
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textSecondary)
                    .padding(.top, LacticSpacing.xs)
            }
        }
    }

    private func exerciseLog(_ log: ExerciseLogDetail, detail: SessionDetailModel.Detail) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            HStack(spacing: LacticSpacing.sm) {
                if let position = detail.positions[log.workoutExerciseID] {
                    PositionBadge(position)
                }
                // Falls back to the id only when the workout could not be read;
                // the web shows the raw id unconditionally.
                Text(detail.exerciseNames[log.workoutExerciseID] ?? String(localized: "Exercise"))
                    .font(.lacticBody.weight(.medium))
                    .foregroundStyle(LacticColor.textPrimary)
            }

            if let notes = log.notes, !notes.isEmpty {
                Text(notes)
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
            }

            ForEach(log.orderedSets) { set in
                HStack {
                    Text("Set \(set.position)")
                        .font(.lacticCaption)
                        .foregroundStyle(LacticColor.textSecondary)
                    Spacer()
                    Text("\(Formatters.weight(set.weightKg, locale: environment.locale)) kg × \(set.reps)")
                        .font(.lacticNumeric)
                        .foregroundStyle(LacticColor.textPrimary)
                }
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
}
