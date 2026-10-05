import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// One workout's exercises and what the coach prescribes for each — the web's
/// workout page.
struct StudioWorkoutEditorView: View {
    @Environment(StudioEnvironment.self) private var environment

    @State private var model: WorkoutEditorModel
    private let client: APIClient
    private let didChangeVolume: () -> Void

    @State private var isPicking = false
    @State private var editing: WorkoutExercise?
    @State private var pendingRemoval: WorkoutExercise?

    /// `didChangeVolume` runs after an exercise is added, edited or removed,
    /// which moves the workout's volume that the programme beside this shows.
    init(
        client: APIClient, programID: Int, weekID: Int, workoutID: Int,
        didChangeVolume: @escaping () -> Void
    ) {
        self.client = client
        self.didChangeVolume = didChangeVolume
        _model = State(initialValue: WorkoutEditorModel(
            client: client, programID: programID, weekID: weekID, workoutID: workoutID
        ))
    }

    var body: some View {
        Group {
            if let workout = model.workout {
                content(workout)
            } else if let failure = model.failure {
                StudioInitialFailureView(failure: failure, title: Text("Workout")) {
                    Task { await model.load() }
                }
            } else {
                LoadingView(String(localized: "Loading workout"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LacticColor.surface)
            }
        }
        .navigationTitle(model.workout?.name ?? String(localized: "Workout"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPicking = true
                } label: {
                    Label("Add exercise", systemImage: "plus")
                }
                .disabled(model.workout == nil || !model.canAddExercise || model.isSubmitting)
            }
        }
        .sheet(isPresented: $isPicking) {
            StudioExercisePicker(client: client) { exercise in
                await model.addExercise(exercise)
            }
        }
        .sheet(item: $editing) { exercise in
            PrescriptionSheet(exercise: exercise, model: model)
        }
        .confirmationDialog(
            "Remove \(pendingRemoval?.exercise.name ?? "")?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: {
                if !$0 {
                    pendingRemoval = nil
                }
            }),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { exercise in
            Button("Remove exercise", role: .destructive) {
                Task { await model.removeExercise(id: exercise.id) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task { await model.load() }
        // Not the first load, which fills the volume in rather than changing it.
        .onChange(of: model.workout?.volumeSets) { old, _ in
            if old != nil {
                didChangeVolume()
            }
        }
    }

    private func content(_ workout: WorkoutDetail) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LacticSpacing.lg) {
                VStack(alignment: .leading, spacing: LacticSpacing.md) {
                    Text(verbatim: Formatters.weekdayName(day: workout.day, locale: environment.locale))
                        .font(.lacticEyebrow)
                        .foregroundStyle(LacticColor.brand)
                        .textCase(.uppercase)
                    Text(verbatim: workout.name)
                        .font(.lacticDisplay)
                        .foregroundStyle(LacticColor.textOnHero)
                    if !workout.volumeSets.isEmpty {
                        FlowLayout(spacing: LacticSpacing.xs) {
                            ForEach(workout.volumeSets.sorted { $0.key < $1.key }, id: \.key) { muscle, sets in
                                VolumeChip(muscleGroup: muscle, sets: sets)
                            }
                        }
                    }
                }
                .padding(LacticSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LacticColor.heroSurface,
                    in: RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
                )

                if let failure = model.failure {
                    StudioActionFailureNotice(failure: failure)
                }

                if model.exercises.isEmpty {
                    StudioEmptyCard(
                        title: "No exercises yet",
                        message: "Add exercises from the catalog, then set their sets, reps and rest.",
                        systemImage: "dumbbell"
                    ) {
                        Button("Add exercise") { isPicking = true }
                            .lacticButton(isEnabled: !model.isSubmitting)
                            .frame(maxWidth: 280)
                    }
                } else {
                    ForEach(model.exercises) { exercise in
                        exerciseCard(exercise)
                    }
                    if !model.canAddExercise {
                        Text("A workout holds up to 26 exercises, one per letter.")
                            .font(.lacticCaption)
                            .foregroundStyle(LacticColor.textMuted)
                    }
                }
            }
            .padding(LacticSpacing.xl)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .background(LacticColor.surface)
        .opacity(model.isSubmitting ? 0.7 : 1)
        .refreshable { await model.load() }
    }

    private func exerciseCard(_ exercise: WorkoutExercise) -> some View {
        HStack(alignment: .top, spacing: LacticSpacing.md) {
            Button {
                editing = exercise
            } label: {
                HStack(alignment: .top, spacing: LacticSpacing.md) {
                    PositionBadge(exercise.position)
                    VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                        Text(verbatim: exercise.exercise.name)
                            .font(.lacticHeadline)
                            .foregroundStyle(LacticColor.textPrimary)
                        Text(verbatim: exercise.exercise.muscleLabel)
                            .font(.lacticCaption)
                            .foregroundStyle(LacticColor.textMuted)
                        Text(verbatim: exercise.prescriptionSummary(locale: environment.locale))
                            .font(.lacticBody.monospacedDigit())
                            .foregroundStyle(LacticColor.textSecondary)
                        if let notes = exercise.notes, !notes.isEmpty {
                            Text(verbatim: notes)
                                .font(.lacticCaption)
                                .italic()
                                .foregroundStyle(LacticColor.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Edits the prescription"))

            Menu {
                Button("Edit prescription", systemImage: "slider.horizontal.3") { editing = exercise }
                Button("Remove exercise", systemImage: "trash", role: .destructive) { pendingRemoval = exercise }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(width: LacticSize.minimumHitTarget, height: LacticSize.minimumHitTarget)
            }
            .accessibilityLabel(Text("Exercise actions"))
        }
        .studioCard()
    }
}

/// Sets, reps, rest, and the optional RIR, suggested weight and note.
private struct PrescriptionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: WorkoutExercise
    let model: WorkoutEditorModel

    @State private var prescription: WorkoutExercisePrescription
    @State private var hasRIR: Bool
    @State private var rir: Int
    @State private var hasWeight: Bool
    @State private var weight: Decimal

    init(exercise: WorkoutExercise, model: WorkoutEditorModel) {
        self.exercise = exercise
        self.model = model
        let prescription = WorkoutExercisePrescription(exercise)
        _prescription = State(initialValue: prescription)
        _hasRIR = State(initialValue: prescription.rir != nil)
        _rir = State(initialValue: prescription.rir ?? 2)
        _hasWeight = State(initialValue: prescription.weight != nil)
        _weight = State(initialValue: prescription.weight ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $prescription.sets, in: 1 ... 20) {
                        LabeledContent("Sets", value: prescription.sets.formatted())
                    }
                    Stepper(value: $prescription.reps, in: 1 ... 100) {
                        LabeledContent("Reps", value: prescription.reps.formatted())
                    }
                    Stepper(value: $prescription.restSeconds, in: 0 ... 600, step: 15) {
                        LabeledContent("Rest", value: String(localized: "\(prescription.restSeconds) s"))
                    }
                }
                Section {
                    Toggle("Reps in reserve", isOn: $hasRIR)
                    if hasRIR {
                        Stepper(value: $rir, in: 0 ... 10) {
                            LabeledContent("RIR", value: rir.formatted())
                        }
                    }
                    Toggle("Suggested weight", isOn: $hasWeight)
                    if hasWeight {
                        LabeledContent("Kilograms") {
                            TextField("kg", value: $weight, format: .number.precision(.fractionLength(0 ... 2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                Section("Coach notes") {
                    TextField("e.g. Pause at the bottom", text: $prescription.notes, axis: .vertical)
                        .lineLimit(2 ... 5)
                }
                if let failure = model.failure {
                    Section {
                        StudioActionFailureNotice(failure: failure)
                    }
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle(Text(verbatim: "\(exercise.position) · \(exercise.exercise.name)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.isSubmitting {
                        ProgressView()
                    } else {
                        Button("Save", action: save).disabled(!final.isValid)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var final: WorkoutExercisePrescription {
        var result = prescription
        result.rir = hasRIR ? rir : nil
        result.weight = hasWeight ? weight : nil
        return result
    }

    private func save() {
        Task {
            if await model.updateExercise(id: exercise.id, to: final) {
                dismiss()
            }
        }
    }
}
