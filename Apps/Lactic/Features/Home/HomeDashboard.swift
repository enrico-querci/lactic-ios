import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct HomeDashboard: View {
    let snapshot: HomeModel.Snapshot
    let locale: AppLocale

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LacticSpacing.xl) {
                if let assignment = snapshot.assignment {
                    if let resumable = snapshot.resumable {
                        HomeWorkoutHero(
                            mode: .resume,
                            workoutID: resumable.workoutID,
                            assignmentID: assignment.id,
                            name: snapshot.workoutName(for: resumable.workoutID) ?? String(localized: "Workout"),
                            week: nil,
                            day: nil,
                            startedAt: resumable.startedAt,
                            exerciseCount: snapshot.featuredExerciseCount,
                            targetSets: snapshot.featuredTargetSets,
                            locale: locale
                        )
                    } else if let next = snapshot.upNext {
                        HomeWorkoutHero(
                            mode: .start,
                            workoutID: next.workout.id,
                            assignmentID: assignment.id,
                            name: next.workout.name,
                            week: next.week.position,
                            day: next.workout.day,
                            startedAt: nil,
                            exerciseCount: snapshot.featuredExerciseCount,
                            targetSets: snapshot.featuredTargetSets,
                            locale: locale
                        )
                    }

                    HomeProgrammeCard(
                        programID: assignment.program.id,
                        name: assignment.program.name,
                        guidance: assignment.notes ?? snapshot.program?.description,
                        completed: snapshot.completedWorkoutCount,
                        total: snapshot.totalWorkoutCount
                    )
                }

                if !snapshot.recent.isEmpty {
                    HomeRecentActivity(
                        sessions: snapshot.recent,
                        workoutNames: snapshot.recent.reduce(into: [:]) { names, session in
                            if let name = snapshot.workoutName(for: session.workoutID) {
                                names[session.workoutID] = name
                            }
                        },
                        locale: locale
                    )
                }
            }
            .padding(LacticSpacing.lg)
        }
    }
}

private enum HomeWorkoutMode: Equatable {
    case resume
    case start
}

private struct HomeWorkoutHero: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let mode: HomeWorkoutMode
    let workoutID: Int
    let assignmentID: Int
    let name: String
    let week: Int?
    let day: Int?
    let startedAt: Date?
    let exerciseCount: Int?
    let targetSets: Int?
    let locale: AppLocale

    var body: some View {
        NavigationLink {
            WorkoutExecutionView(workoutID: workoutID, assignmentID: assignmentID)
        } label: {
            VStack(alignment: .leading, spacing: LacticSpacing.xl) {
                Label {
                    if mode == .resume {
                        Text("Workout in progress")
                    } else {
                        Text("Up next")
                    }
                } icon: {
                    Image(systemName: mode == .resume ? "bolt.fill" : "figure.strengthtraining.traditional")
                }
                .font(.lacticEyebrow)
                .foregroundStyle(LacticColor.brand)

                VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                    Text(name)
                        .font(.lacticTitle)
                        .foregroundStyle(LacticColor.textOnHero)
                        .fixedSize(horizontal: false, vertical: true)
                    contextLine
                        .font(.subheadline)
                        .foregroundStyle(LacticColor.textOnHero)
                }

                HStack {
                    if mode == .resume {
                        Text("Resume workout")
                            .font(.lacticHeadline)
                    } else {
                        Text("Start workout")
                            .font(.lacticHeadline)
                    }
                    Spacer(minLength: LacticSpacing.sm)
                    Image(systemName: "arrow.right")
                        .font(.lacticHeadline)
                }
                .foregroundStyle(LacticColor.heroSurface)
                .padding(.horizontal, LacticSpacing.lg)
                .frame(minHeight: 52)
                .background(LacticColor.brand, in: RoundedRectangle(cornerRadius: LacticRadius.control))
            }
            .padding(LacticSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LacticColor.heroSurface, in: RoundedRectangle(cornerRadius: LacticRadius.card))
        }
        .buttonStyle(.plain)
        .accessibilityHint(accessibilityHint)
    }

    private var accessibilityHint: LocalizedStringKey {
        switch mode {
        case .resume:
            "Returns to your active workout"
        case .start:
            "Opens this workout"
        }
    }

    @ViewBuilder
    private var contextLine: some View {
        if let startedAt {
            Text("Started \(Formatters.dateTime(startedAt, locale: locale))")
        } else if let week, let day {
            Text("Week \(week) · \(Formatters.weekdayName(day: day, locale: locale))")
        }

        if let exerciseCount, let targetSets {
            if dynamicTypeSize.isAccessibilitySize {
                Text("\(exerciseCount) exercises")
                Text("\(targetSets) target sets")
            } else {
                Text("\(exerciseCount) exercises · \(targetSets) target sets")
            }
        }
    }
}

private struct HomeProgrammeCard: View {
    let programID: Int
    let name: String
    let guidance: String?
    let completed: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text("Current programme")
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.textPrimary)

            NavigationLink {
                ProgramDetailView(programID: programID)
            } label: {
                VStack(alignment: .leading, spacing: LacticSpacing.md) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(name)
                            .font(.title3.bold())
                            .foregroundStyle(LacticColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: LacticSpacing.sm)
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(LacticColor.accent)
                    }

                    if total > 0 {
                        VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                            Text("\(completed) of \(total) workouts completed")
                                .font(.lacticCaption.monospacedDigit())
                                .foregroundStyle(LacticColor.textSecondary)
                            ProgressView(value: Double(completed), total: Double(total))
                                .tint(LacticColor.accent)
                                .accessibilityHidden(true)
                        }
                    }

                    if let guidance, !guidance.isEmpty {
                        Label(guidance, systemImage: "text.bubble")
                            .font(.subheadline)
                            .foregroundStyle(LacticColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(LacticSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LacticColor.surfaceElevated, in: RoundedRectangle(cornerRadius: LacticRadius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: LacticRadius.card)
                        .strokeBorder(LacticColor.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct HomeRecentActivity: View {
    let sessions: [WorkoutSession]
    let workoutNames: [Int: String]
    let locale: AppLocale

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text("Recent activity")
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    NavigationLink {
                        SessionDetailView(sessionID: session.id)
                    } label: {
                        HomeActivityRow(
                            name: workoutNames[session.workoutID] ?? String(localized: "Workout"),
                            session: session,
                            locale: locale
                        )
                    }
                    .buttonStyle(.plain)

                    if index < sessions.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(LacticColor.surfaceElevated, in: RoundedRectangle(cornerRadius: LacticRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: LacticRadius.card)
                    .strokeBorder(LacticColor.border, lineWidth: 1)
            }
        }
    }
}

private struct HomeActivityRow: View {
    let name: String
    let session: WorkoutSession
    let locale: AppLocale

    var body: some View {
        HStack(spacing: LacticSpacing.md) {
            Image(systemName: "checkmark")
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.heroSurface)
                .frame(width: 40, height: 40)
                .background(LacticColor.brand, in: RoundedRectangle(cornerRadius: LacticRadius.control))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text(name)
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.textPrimary)
                    .lineLimit(2)
                if let startedAt = session.startedAt {
                    Text(Formatters.dateTime(startedAt, locale: locale))
                        .font(.lacticCaption)
                        .foregroundStyle(LacticColor.textSecondary)
                }
            }

            Spacer(minLength: LacticSpacing.sm)

            if let duration = ClientFormat.duration(of: session) {
                Text(duration)
                    .font(.lacticCaption.monospacedDigit())
                    .foregroundStyle(LacticColor.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LacticColor.textMuted)
                .accessibilityHidden(true)
        }
        .padding(LacticSpacing.lg)
        .contentShape(.rect)
    }
}

struct HomeEmptyState: View {
    var body: some View {
        VStack(spacing: LacticSpacing.xl) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.lacticDisplay)
                .foregroundStyle(LacticColor.brand)
                .accessibilityHidden(true)
            VStack(spacing: LacticSpacing.sm) {
                Text("Ready when your coach is")
                    .font(.lacticTitle)
                    .foregroundStyle(LacticColor.textOnHero)
                    .multilineTextAlignment(.center)
                Text("Once your coach assigns a programme, your next workout will appear here.")
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textOnHero)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(LacticSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LacticColor.heroSurface)
    }
}
