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

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            header
            targetRow
            assist

            ExerciseDemonstration(
                cacheKey: "exercise-\(workoutExercise.exercise.id)",
                hasAnimation: workoutExercise.exercise.hasAnimation,
                load: animationLoader
            )

            sets
            actions
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

    /// The timer deliberately does **not** live here.
    ///
    /// It did, and starting it reflowed the whole card: the running `1:25` in
    /// the large timer font plus a Skip button is far wider than the `Rest 90s`
    /// button it replaces, so the exercise name wrapped to two lines and
    /// everything below shifted down — mid-workout, under a thumb. It now sits
    /// on its own row beside "Add set", where it can change width freely and is
    /// closer to the action that triggers it.
    private var header: some View {
        HStack(spacing: LacticSpacing.sm) {
            PositionBadge(workoutExercise.position)
            Text(workoutExercise.exercise.name)
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.textPrimary)
            Spacer(minLength: LacticSpacing.sm)
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
                Text(notes)
                    .font(.lacticCaption.italic())
                    .foregroundStyle(LacticColor.textSecondary)
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
            ForEach(loggedSets) { set in
                HStack(spacing: LacticSpacing.sm) {
                    Text("\(set.position)")
                        .font(.lacticCaption.monospacedDigit())
                        .foregroundStyle(LacticColor.textSecondary)
                        .frame(width: 20, alignment: .leading)

                    NumericField(kind: .weight, value: set.weightKg) { newValue in
                        Task {
                            await recorder.updateSet(
                                set.id, in: workoutExercise.id, weightKg: newValue, reps: nil
                            )
                        }
                    }

                    NumericField(kind: .reps, value: Decimal(set.reps)) { newValue in
                        Task {
                            await recorder.updateSet(
                                set.id, in: workoutExercise.id,
                                weightKg: nil, reps: Int(truncating: newValue as NSNumber)
                            )
                        }
                    }

                    Button {
                        Task { await recorder.deleteSet(set.id, in: workoutExercise.id) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(LacticColor.textSecondary)
                            .frame(
                                width: LacticSize.minimumHitTarget,
                                height: LacticSize.minimumHitTarget
                            )
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete set \(set.position)")
                }
            }
        }
    }

    /// Adding is unbounded on purpose: exceeding the coach's target is the
    /// "add extra sets" feature, and the target line above is a prescription,
    /// not a limit.
    private var actions: some View {
        HStack(spacing: LacticSpacing.sm) {
            Button("Add set") {
                Task { await logSet() }
            }
            .lacticButton(.secondary, size: .small)
            .fixedSize()

            Spacer(minLength: LacticSpacing.sm)

            RestTimerView(
                duration: workoutExercise.effectiveRestSeconds,
                deadline: $restDeadline,
                onFinished: finishRest
            )
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
