import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct ProgramDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    let programID: Int

    @State private var model: ProgramDetailModel?

    var body: some View {
        LoadableView(model) { program in
            content(program)
        }
        .background(LacticColor.surface)
        .navigationTitle(model?.state.value?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let model = model ?? ProgramDetailModel(client: environment.client, programID: programID)
            self.model = model
            await model.load()
        }
    }

    private func content(_ program: ProgramDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LacticSpacing.xl) {
                if let description = program.description, !description.isEmpty {
                    Text(description)
                        .font(.lacticBody)
                        .foregroundStyle(LacticColor.textSecondary)
                }

                ForEach(program.orderedWeeks) { week in
                    weekSection(week, assignmentID: program.assignmentID)
                }
            }
            .padding(LacticSpacing.lg)
        }
    }

    private func weekSection(_ week: Week, assignmentID: Int) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text("Week \(week.position)")
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.textPrimary)

            if week.workouts.isEmpty {
                Text("No workouts in this week.")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textMuted)
            } else {
                ForEach(week.orderedWorkouts) { workout in
                    NavigationLink {
                        WorkoutExecutionView(workoutID: workout.id, assignmentID: assignmentID)
                    } label: {
                        WorkoutRow(workout: workout, locale: environment.locale)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// A workout as it appears inside a programme. Tapping one opens the execution
/// screen, carrying the assignment id — a session belongs to an assignment, and
/// the workout payload has no way to supply it.
private struct WorkoutRow: View {
    let workout: Workout
    let locale: AppLocale

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(workout.name)
                    .font(.lacticBody.weight(.medium))
                    .foregroundStyle(LacticColor.textPrimary)
                Spacer(minLength: LacticSpacing.sm)
                Text(Formatters.weekdayName(day: workout.day, locale: locale))
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
            }

            if !workout.volumeSets.isEmpty {
                // Wraps rather than scrolls: a workout can touch several muscle
                // groups and a horizontally scrolling row hides them.
                FlowLayout(spacing: LacticSpacing.xs) {
                    ForEach(ClientFormat.orderedVolume(workout.volumeSets), id: \.muscleGroup) { entry in
                        VolumeChip(muscleGroup: entry.muscleGroup, sets: entry.sets)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LacticSpacing.md)
        .background(LacticColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
                .strokeBorder(LacticColor.border, lineWidth: 1)
        }
    }
}
