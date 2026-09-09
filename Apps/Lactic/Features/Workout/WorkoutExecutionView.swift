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
    @State private var sessionNoteDraft: String?
    @FocusState private var isEditingSessionNote: Bool

    var body: some View {
        LoadableView(model) { context in
            if let model {
                content(context, model: model)
            }
        }
        .background(LacticColor.surface)
        .navigationTitle(model?.state.value?.workout.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        // Scoped to this screen and always restored, so it cannot leak into the
        // rest of the app and quietly drain the battery.
        .onDisappear {
            RestAlerts.setKeepScreenAwake(false)
            RestAlerts.cancelAll()
        }
        .onChange(of: model?.isSessionActive ?? false) { _, isActive in
            RestAlerts.setKeepScreenAwake(isActive)
            // Ask here rather than on the first logged set: the client has just
            // started training, nothing is in flight, and iOS only ever shows
            // this prompt once. Covers a resumed session too, since that also
            // flips this flag.
            if isActive {
                Task { await RestAlerts.requestAuthorizationIfNeeded() }
            }
        }
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
                    sessionNotes(recorder)
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

    /// How the whole session went, as opposed to a single exercise.
    ///
    /// The API has supported `workout_sessions.notes` since the logging
    /// endpoints landed and AGENTS.md §4.1 lists it as a client feature, but
    /// lactic-web never built UI for it. The outstanding web work is recorded
    /// in AGENTS.md §8.
    private func sessionNotes(_ recorder: WorkoutRecorder) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text("Session notes")
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.textPrimary)

            TextField("How did the whole session go?", text: sessionNoteBinding(recorder), axis: .vertical)
                .font(.lacticBody)
                .lineLimit(2 ... 5)
                .textFieldStyle(.roundedBorder)
        }
    }

    /// Commits on blur rather than on every keystroke: typing a sentence would
    /// otherwise queue one write per character.
    private func sessionNoteBinding(_ recorder: WorkoutRecorder) -> Binding<String> {
        Binding(
            get: { sessionNoteDraft ?? recorder.notes ?? "" },
            set: { sessionNoteDraft = $0 }
        )
    }

    private func completeButton(_ model: WorkoutExecutionModel) -> some View {
        Button("Finish workout") {
            Task {
                await commitSessionNote(model)
                await model.complete()
            }
        }
        .lacticButton()
        .padding(.top, LacticSpacing.sm)
    }

    private func commitSessionNote(_ model: WorkoutExecutionModel) async {
        guard let recorder = model.recorder, let draft = sessionNoteDraft else { return }
        guard draft != (recorder.notes ?? "") else { return }
        await recorder.setSessionNotes(draft.isEmpty ? nil : draft)
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
