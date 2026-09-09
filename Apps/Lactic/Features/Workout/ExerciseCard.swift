import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// One exercise while training: the coach's prescription, what was lifted last
/// time, the demonstration, and the sets being logged.
struct ExerciseCard: View {
    let workoutExercise: WorkoutExercise
    let recorder: WorkoutRecorder
    let lastTime: SetLog?
    let locale: AppLocale
    let animationLoader: @Sendable () async throws -> Data

    @State private var isEditingNotes = false
    @State private var noteDraft = ""
    @State private var restDeadline: Date?
    @State private var isLogging = false

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            ExerciseTrainingHeader(
                position: workoutExercise.position,
                name: workoutExercise.exercise.name,
                loggedCount: loggedSets.count,
                targetCount: workoutExercise.sets
            )
            targetRow
            assist

            ExerciseDemonstration(
                cacheKey: "exercise-\(workoutExercise.exercise.id)",
                hasAnimation: workoutExercise.exercise.hasAnimation,
                load: animationLoader
            )

            Divider().overlay(LacticColor.border)
            sets
            Button(action: addSet) {
                Label {
                    if loggedSets.count >= workoutExercise.sets {
                        Text("Log extra set")
                    } else {
                        Text("Log set")
                    }
                } icon: {
                    Image(systemName: "checkmark")
                }
            }
            .lacticButton(isEnabled: !isLogging)
            RestTimerView(
                duration: workoutExercise.effectiveRestSeconds,
                deadline: $restDeadline,
                onFinished: finishRest
            )
            notes
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

    private var targetRow: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xs) {
            FlowLayout(spacing: LacticSpacing.xs) {
                StatusBadge("Target \(workoutExercise.sets) × \(workoutExercise.reps)")
                if let weight = workoutExercise.weight {
                    StatusBadge("\(Formatters.weight(weight, locale: locale)) kg", tone: .informative)
                }
                if let rir = workoutExercise.rir {
                    StatusBadge("RIR \(rir)")
                }
            }
            if let notes = workoutExercise.notes, !notes.isEmpty {
                Label(notes, systemImage: "text.bubble")
                    .font(.subheadline)
                    .foregroundStyle(LacticColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, LacticSpacing.sm)
            }
        }
    }

    /// Deliberately distinguishes "no history" from "we could not load it".
    /// Collapsing them would tell a returning client they have never done an
    /// exercise they have done for months.
    @ViewBuilder
    private var assist: some View {
        if let lastTime {
            Text("Last time: \(Formatters.weight(lastTime.weightKg, locale: locale)) kg × \(lastTime.reps)")
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textSecondary)
        } else {
            Text("First time doing this")
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textMuted)
        }
    }

    private var loggedSets: [WorkoutRecorder.Set] {
        recorder.entries[workoutExercise.id]?.orderedSets ?? []
    }

    private var sets: some View {
        VStack(spacing: LacticSpacing.sm) {
            if loggedSets.isEmpty {
                Text("Log your first set after you finish it. Adjust weight and reps below.")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, LacticSpacing.sm)
            }
            ForEach(loggedSets) { set in
                LoggedSetRow(set: set, exerciseID: workoutExercise.id, recorder: recorder)
            }
        }
    }

    /// Adding is unbounded on purpose: exceeding the coach's target is the
    /// "add extra sets" feature, and the target line above is a prescription,
    /// not a limit.
    private func addSet() {
        guard !isLogging else { return }
        isLogging = true
        Task {
            await logSet()
            isLogging = false
        }
    }

    /// Logs the set and starts the rest, because those are one action.
    ///
    /// Reaching for the phone a second time to press "rest" right after a heavy
    /// set is exactly the interaction worth removing; the timer can still be
    /// started or skipped by hand.
    private func logSet() async {
        await recorder.addSet(to: workoutExercise)

        let deadline = Date().addingTimeInterval(TimeInterval(workoutExercise.effectiveRestSeconds))
        restDeadline = deadline
        await RestAlerts.schedule(
            for: String(workoutExercise.id),
            at: deadline,
            exerciseName: workoutExercise.exercise.name
        )
    }

    /// Runs when the countdown reaches zero **or** the client skips it. Either
    /// way the pending notification has to go: firing it afterwards would
    /// announce a rest they have already finished.
    private func finishRest() {
        RestAlerts.cancel(for: String(workoutExercise.id))
        RestAlerts.playFinishedHaptic()
    }

    @ViewBuilder
    private var notes: some View {
        if isEditingNotes {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                TextField("How did it feel?", text: $noteDraft, axis: .vertical)
                    .font(.lacticBody)
                    .lineLimit(1 ... 4)
                    .textFieldStyle(.roundedBorder)
                Button("Save note") {
                    Task {
                        await recorder.setNotes(
                            noteDraft.isEmpty ? nil : noteDraft, for: workoutExercise
                        )
                        isEditingNotes = false
                    }
                }
                .lacticButton(.secondary, size: .small)
                .fixedSize()
            }
        } else if let existing = recorder.entries[workoutExercise.id]?.notes, !existing.isEmpty {
            Button {
                noteDraft = existing
                isEditingNotes = true
            } label: {
                Text(existing)
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        } else {
            Button("Add a note") {
                noteDraft = ""
                isEditingNotes = true
            }
            .lacticButton(.secondary, size: .small)
        }
    }
}
