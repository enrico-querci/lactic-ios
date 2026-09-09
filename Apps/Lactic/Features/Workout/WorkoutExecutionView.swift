import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// The screen a client uses while actually training.
struct WorkoutExecutionView: View {
    @Environment(AppEnvironment.self) private var environment
    let workoutID: Int
    let assignmentID: Int

    @State private var model: WorkoutExecutionModel?

    var body: some View {
        LoadableView(model) { context in
            if let model {
                content(context, model: model)
            }
        }
        .background(LacticColor.surface)
        .navigationTitle(model?.state.value?.workout.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let model = model ?? WorkoutExecutionModel(
                client: environment.client,
                outbox: environment.outbox,
                workoutID: workoutID,
                assignmentID: assignmentID
            )
            self.model = model
            await model.load()
        }
    }

    private func content(_ context: WorkoutExecutionModel.Context, model: WorkoutExecutionModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LacticSpacing.lg) {
                // A failed write is shown loudly and stays until dismissed: a
                // set that silently did not save is one the trainee will not
                // think to re-enter.
                if let actionError = model.actionError {
                    ErrorBanner(message: actionError) { model.dismissError() }
                }

                if let recorder = model.recorder {
                    syncIndicator(recorder)
                    ForEach(context.workout.orderedExercises) { exercise in
                        ExerciseCard(
                            workoutExercise: exercise,
                            recorder: recorder,
                            lastTime: context.lastTime[exercise.exercise.id],
                            locale: environment.locale,
                            animationLoader: model.animationLoader(exerciseID: exercise.exercise.id)
                        )
                    }
                    completeButton(model)
                } else {
                    summary(context, model: model)
                }
            }
            .padding(LacticSpacing.lg)
        }
    }

    /// Before the session starts: what the coach prescribed, and one button.
    private func summary(
        _ context: WorkoutExecutionModel.Context, model: WorkoutExecutionModel
    ) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.lg) {
            if !context.workout.volumeSets.isEmpty {
                FlowLayout(spacing: LacticSpacing.xs) {
                    ForEach(ClientFormat.orderedVolume(context.workout.volumeSets), id: \.muscleGroup) {
                        VolumeChip(muscleGroup: $0.muscleGroup, sets: $0.sets)
                    }
                }
            }

            ForEach(context.workout.orderedExercises) { entry in
                HStack(spacing: LacticSpacing.sm) {
                    PositionBadge(entry.position)
                    VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                        Text(entry.exercise.name)
                            .font(.lacticBody.weight(.medium))
                            .foregroundStyle(LacticColor.textPrimary)
                        Text(target(for: entry))
                            .font(.lacticCaption)
                            .foregroundStyle(LacticColor.textSecondary)
                    }
                    Spacer()
                }
            }

            Button(model.isStarting ? "Starting…" : "Start workout") {
                Task { await model.start() }
            }
            .lacticButton(isEnabled: !model.isStarting)
        }
    }

    @ViewBuilder
    private func syncIndicator(_ recorder: WorkoutRecorder) -> some View {
        if recorder.syncProgress.blocked > 0 {
            ErrorBanner(
                message: String(
                    localized: "\(recorder.syncProgress.blocked) change(s) could not be saved."
                )
            ) {}
        } else if !recorder.syncProgress.isSettled {
            HStack(spacing: LacticSpacing.sm) {
                ProgressView().controlSize(.small)
                Text("Saving…")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
            }
        }
    }

    private func completeButton(_ model: WorkoutExecutionModel) -> some View {
        Button("Finish workout") {
            Task { await model.complete() }
        }
        .lacticButton()
        .padding(.top, LacticSpacing.sm)
    }

    private func target(for entry: WorkoutExercise) -> String {
        var parts = ["\(entry.sets) × \(entry.reps)"]
        if let weight = entry.weight {
            parts.append("\(Formatters.weight(weight, locale: environment.locale)) kg")
        }
        if let rir = entry.rir {
            parts.append("RIR \(rir)")
        }
        return parts.joined(separator: " · ")
    }
}
