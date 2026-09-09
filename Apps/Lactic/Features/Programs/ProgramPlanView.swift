import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct ProgramPlanView: View {
    let snapshot: ProgramDetailModel.Snapshot
    let locale: AppLocale

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LacticSpacing.xl) {
                ProgrammePlanOverview(snapshot: snapshot)

                ForEach(snapshot.program.orderedWeeks) { week in
                    ProgrammeWeekSection(
                        week: week,
                        assignmentID: snapshot.program.assignmentID,
                        progress: snapshot.progress(in: week),
                        completedWorkoutIDs: snapshot.completedWorkoutIDs,
                        inProgressWorkoutIDs: snapshot.inProgressWorkoutIDs,
                        locale: locale
                    )
                }
            }
            .padding(LacticSpacing.lg)
        }
    }
}

private struct ProgrammePlanOverview: View {
    let snapshot: ProgramDetailModel.Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xl) {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                Text("Training plan")
                    .font(.lacticEyebrow)
                    .foregroundStyle(LacticColor.brand)
                Text(snapshot.program.name)
                    .font(.lacticTitle)
                    .foregroundStyle(LacticColor.textOnHero)
                    .fixedSize(horizontal: false, vertical: true)
                if let description = snapshot.program.description, !description.isEmpty {
                    Text(description)
                        .font(.lacticBody)
                        .foregroundStyle(LacticColor.textOnHero)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: LacticSpacing.xl) {
                ProgrammeMetric(value: snapshot.program.weeks.count, label: String(localized: "Weeks"))
                ProgrammeMetric(value: snapshot.totalWorkoutCount, label: String(localized: "Workouts"))
            }

            if snapshot.totalWorkoutCount > 0 {
                VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                    Text("\(snapshot.completedWorkoutCount) of \(snapshot.totalWorkoutCount) workouts completed")
                        .font(.lacticCaption.monospacedDigit())
                        .foregroundStyle(LacticColor.textOnHero)
                    ProgressView(
                        value: Double(snapshot.completedWorkoutCount),
                        total: Double(snapshot.totalWorkoutCount)
                    )
                    .tint(LacticColor.brand)
                    .accessibilityHidden(true)
                }
            }
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LacticColor.heroSurface, in: RoundedRectangle(cornerRadius: LacticRadius.card))
    }
}

private struct ProgrammeMetric: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xs) {
            Text(value.formatted())
                .font(.lacticNumeric)
                .foregroundStyle(LacticColor.brand)
            Text(label)
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textOnHero)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ProgrammeWeekSection: View {
    let week: Week
    let assignmentID: Int
    let progress: (completed: Int, total: Int)
    let completedWorkoutIDs: Set<Int>
    let inProgressWorkoutIDs: Set<Int>
    let locale: AppLocale

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Week \(week.position)")
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.textPrimary)
                Spacer(minLength: LacticSpacing.sm)
                Text("\(progress.completed) of \(progress.total) complete")
                    .font(.lacticCaption.monospacedDigit())
                    .foregroundStyle(LacticColor.textSecondary)
            }

            if week.workouts.isEmpty {
                Text("No workouts in this week.")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textMuted)
                    .padding(LacticSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LacticColor.surfaceElevated,
                        in: RoundedRectangle(cornerRadius: LacticRadius.card)
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(week.orderedWorkouts.enumerated()), id: \.element.id) { index, workout in
                        NavigationLink {
                            WorkoutExecutionView(workoutID: workout.id, assignmentID: assignmentID)
                        } label: {
                            ProgrammeWorkoutRow(
                                workout: workout,
                                status: workoutStatus(for: workout.id),
                                locale: locale
                            )
                        }
                        .buttonStyle(.plain)

                        if index < week.workouts.count - 1 {
                            Divider().padding(.leading, LacticSpacing.lg)
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

    private func workoutStatus(for workoutID: Int) -> ProgramDetailModel.WorkoutStatus {
        if inProgressWorkoutIDs.contains(workoutID) {
            return .inProgress
        }
        if completedWorkoutIDs.contains(workoutID) {
            return .completed
        }
        return .upcoming
    }
}

private struct ProgrammeWorkoutRow: View {
    let workout: Workout
    let status: ProgramDetailModel.WorkoutStatus
    let locale: AppLocale

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            HStack(spacing: LacticSpacing.md) {
                Text(Formatters.weekdayName(day: workout.day, locale: locale))
                    .font(.lacticEyebrow)
                    .foregroundStyle(LacticColor.heroSurface)
                    .padding(.horizontal, LacticSpacing.sm)
                    .frame(minWidth: 48, minHeight: 48)
                    .background(LacticColor.brand, in: RoundedRectangle(cornerRadius: LacticRadius.control))

                VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                    Text(workout.name)
                        .font(.lacticHeadline)
                        .foregroundStyle(LacticColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: LacticSpacing.sm) {
                        workoutStatus
                        if targetSetCount > 0 {
                            Text("\(targetSetCount) target sets")
                                .font(.lacticCaption.monospacedDigit())
                                .foregroundStyle(LacticColor.textSecondary)
                        }
                    }
                }

                Spacer(minLength: LacticSpacing.sm)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LacticColor.textMuted)
                    .accessibilityHidden(true)
            }

            if !workout.volumeSets.isEmpty {
                FlowLayout(spacing: LacticSpacing.xs) {
                    ForEach(ClientFormat.orderedVolume(workout.volumeSets), id: \.muscleGroup) { entry in
                        VolumeChip(muscleGroup: entry.muscleGroup, sets: entry.sets)
                    }
                }
                .padding(.leading, 60)
            }
        }
        .padding(LacticSpacing.lg)
        .contentShape(.rect)
        .accessibilityHint("Opens this workout")
    }

    private var targetSetCount: Int {
        workout.volumeSets.values.reduce(0, +)
    }

    @ViewBuilder
    private var workoutStatus: some View {
        switch status {
        case .completed:
            Label("Completed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(LacticColor.success)
        case .inProgress:
            Label("In progress", systemImage: "bolt.fill")
                .foregroundStyle(LacticColor.info)
        case .upcoming:
            Label("Upcoming", systemImage: "circle")
                .foregroundStyle(LacticColor.textMuted)
        }
    }
}
