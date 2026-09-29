import LacticCore
import LacticKit
import LacticUI
import SwiftUI

// The programme builder is one screen with several sheets that share its
// model, so they live together.
// swiftlint:disable file_length

/// One programme's weeks and the workouts on each day — the web's programme
/// page, where a coach builds the plan.
struct StudioProgramBuilderView: View {
    @Environment(StudioEnvironment.self) private var environment
    @Environment(StudioNavigator.self) private var navigator

    @State private var model: ProgramBuilderModel
    private let name: String

    @State private var sheet: BuilderSheet?
    @State private var pendingWeekDeletion: Week?
    @State private var pendingWorkoutDeletion: WorkoutRef?
    @State private var templateSource: WorkoutRef?
    @State private var templateName = ""

    init(client: APIClient, programID: Int, name: String) {
        self.name = name
        _model = State(initialValue: ProgramBuilderModel(client: client, programID: programID))
    }

    var body: some View {
        Group {
            if let program = model.program {
                content(program)
            } else if let failure = model.failure {
                StudioInitialFailureView(failure: failure, title: Text(verbatim: name)) {
                    Task { await model.load() }
                }
            } else {
                LoadingView(String(localized: "Loading programme"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LacticColor.surface)
            }
        }
        .navigationTitle(model.program?.name ?? name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.addWeek() }
                } label: {
                    Label("Add week", systemImage: "plus.rectangle.on.rectangle")
                }
                .disabled(model.program == nil || model.isSubmitting)
            }
        }
        .sheet(item: $sheet, content: sheetContent)
        .confirmationDialog(
            "Delete this week and all its workouts?",
            isPresented: isPresented($pendingWeekDeletion),
            titleVisibility: .visible,
            presenting: pendingWeekDeletion
        ) { week in
            Button("Delete week", role: .destructive) {
                Task { await model.deleteWeek(id: week.id) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete \(pendingWorkoutDeletion?.workout.name ?? "")?",
            isPresented: isPresented($pendingWorkoutDeletion),
            titleVisibility: .visible,
            presenting: pendingWorkoutDeletion
        ) { ref in
            Button("Delete workout", role: .destructive) {
                Task { await model.deleteWorkout(weekID: ref.weekID, id: ref.workout.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Sessions clients already logged against it are deleted too.")
        }
        .alert("Save as template", isPresented: isPresented($templateSource), presenting: templateSource) { ref in
            TextField("Template name", text: $templateName)
            Button("Save") {
                Task { await model.saveAsTemplate(workoutID: ref.workout.id, name: templateName) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("A template can be added to any week of any programme.")
        }
        // On every return, not once: the workout editor changes the volume
        // this screen summarises.
        .onAppear { Task { await model.load() } }
    }

    private func content(_ program: CoachProgram) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LacticSpacing.xl) {
                header(program)

                if let failure = model.failure {
                    StudioActionFailureNotice(failure: failure)
                }

                if model.orderedWeeks.isEmpty {
                    StudioEmptyCard(
                        title: "No weeks yet",
                        message: "Add the first week to start building the programme.",
                        systemImage: "calendar"
                    ) {
                        Button("Add week") { Task { await model.addWeek() } }
                            .lacticButton(isEnabled: !model.isSubmitting)
                            .frame(maxWidth: 280)
                    }
                } else {
                    ForEach(model.orderedWeeks) { week in
                        weekCard(week)
                    }
                }
            }
            .padding(LacticSpacing.xl)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
        .background(LacticColor.surface)
        .opacity(model.isSubmitting ? 0.7 : 1)
        .refreshable { await model.load() }
    }

    private func header(_ program: CoachProgram) -> some View {
        HStack(alignment: .top, spacing: LacticSpacing.md) {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                Text("Programme")
                    .font(.lacticEyebrow)
                    .foregroundStyle(LacticColor.brand)
                    .textCase(.uppercase)
                Text(verbatim: program.name)
                    .font(.lacticDisplay)
                    .foregroundStyle(LacticColor.textOnHero)
                if let description = program.description, !description.isEmpty {
                    Text(verbatim: description)
                        .font(.lacticBody)
                        .foregroundStyle(LacticColor.textOnHero.opacity(0.78))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Edit") { sheet = .details }
                .lacticButton(.secondary, size: .small)
                .fixedSize()
        }
        .padding(LacticSpacing.xl)
        .background(LacticColor.heroSurface, in: RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous))
    }

    private func weekCard(_ week: Week) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            HStack {
                Text("Week \(week.position)")
                    .font(.lacticTitle)
                Spacer()
                Button("Add workout", systemImage: "plus") { sheet = .addWorkout(weekID: week.id) }
                    .lacticButton(.secondary, size: .small)
                    .fixedSize()
                Menu {
                    Button("Delete week", systemImage: "trash", role: .destructive) { pendingWeekDeletion = week }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .frame(width: LacticSize.minimumHitTarget, height: LacticSize.minimumHitTarget)
                }
                .accessibilityLabel(Text("Week actions"))
            }

            let workouts = week.orderedWorkouts
            if workouts.isEmpty {
                Text("No workouts this week yet.")
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textSecondary)
            } else {
                ForEach(workouts) { workout in
                    workoutRow(workout, weekID: week.id)
                }
            }
        }
        .studioCard(radius: LacticRadius.card)
    }

    private func workoutRow(_ workout: Workout, weekID: Int) -> some View {
        let ref = WorkoutRef(weekID: weekID, workout: workout)
        return HStack(spacing: LacticSpacing.md) {
            NavigationLink(value: StudioRoute.workout(
                programID: model.programID, weekID: weekID, workoutID: workout.id, name: workout.name
            )) {
                HStack(alignment: .top, spacing: LacticSpacing.md) {
                    Text(verbatim: Formatters.weekdayName(day: workout.day, locale: environment.locale))
                        .font(.lacticCaption.weight(.semibold))
                        .foregroundStyle(LacticColor.textSecondary)
                        .frame(width: 44, alignment: .leading)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                        Text(verbatim: workout.name)
                            .font(.lacticHeadline)
                            .foregroundStyle(LacticColor.textPrimary)
                        if !workout.volumeSets.isEmpty {
                            FlowLayout(spacing: LacticSpacing.xs) {
                                ForEach(workout.volumeSets.sorted { $0.key < $1.key }, id: \.key) { muscle, sets in
                                    VolumeChip(muscleGroup: muscle, sets: sets)
                                }
                            }
                        } else {
                            Text("No exercises yet")
                                .font(.lacticCaption)
                                .foregroundStyle(LacticColor.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                workoutActions(ref)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(width: LacticSize.minimumHitTarget, height: LacticSize.minimumHitTarget)
            }
            .accessibilityLabel(Text("Workout actions"))
        }
        .padding(LacticSpacing.md)
        .background(LacticColor.surface, in: RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous))
        .contextMenu { workoutActions(ref) }
    }

    @ViewBuilder
    private func workoutActions(_ ref: WorkoutRef) -> some View {
        Button("Rename or move", systemImage: "pencil") { sheet = .editWorkout(ref) }
        Button("Duplicate", systemImage: "plus.square.on.square") { sheet = .duplicate(ref) }
        Button("Save as template", systemImage: "square.and.arrow.down") {
            templateName = ref.workout.name
            templateSource = ref
        }
        Button("Delete workout", systemImage: "trash", role: .destructive) { pendingWorkoutDeletion = ref }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: BuilderSheet) -> some View {
        switch sheet {
        case .details:
            ProgramDetailsSheet(
                title: "Edit programme", saveTitle: "Save",
                name: model.program?.name ?? "", description: model.program?.description ?? ""
            ) { name, description in
                await model.updateDetails(name: name, description: description) ? nil : model.failure
            }
        case .addWorkout(let weekID):
            AddWorkoutSheet(model: model, weekID: weekID) { workout in
                navigator.push(.workout(
                    programID: model.programID, weekID: weekID, workoutID: workout.id, name: workout.name
                ))
            }
        case .editWorkout(let ref):
            WorkoutPlacementSheet(
                mode: .edit, model: model, source: ref, weeks: model.orderedWeeks
            )
        case .duplicate(let ref):
            WorkoutPlacementSheet(
                mode: .duplicate, model: model, source: ref, weeks: model.orderedWeeks
            )
        }
    }

    private func isPresented(_ value: Binding<(some Any)?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: {
            if !$0 {
                value.wrappedValue = nil
            }
        })
    }
}

/// A workout together with the week it sits in, which every workout endpoint
/// needs in its path.
struct WorkoutRef: Hashable {
    let weekID: Int
    let workout: Workout
}

private enum BuilderSheet: Identifiable, Hashable {
    case details
    case addWorkout(weekID: Int)
    case editWorkout(WorkoutRef)
    case duplicate(WorkoutRef)

    var id: Self {
        self
    }
}

/// A day of the programme week, 1-7, as a picker.
private struct DayPicker: View {
    @Environment(StudioEnvironment.self) private var environment
    @Binding var day: Int

    var body: some View {
        Picker("Day", selection: $day) {
            ForEach(1 ... 7, id: \.self) { day in
                Text(verbatim: Formatters.weekdayName(day: day, locale: environment.locale)).tag(day)
            }
        }
    }
}

/// Adds a workout to a week: a new one by name, or a saved template.
private struct AddWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss

    let model: ProgramBuilderModel
    let weekID: Int
    /// Called with a newly created (not template-made) workout, which is
    /// empty and so worth opening straight away.
    let openNewWorkout: (Workout) -> Void

    private enum Source: Hashable {
        case new
        case template
    }

    @State private var source = Source.new
    @State private var name = ""
    @State private var templateID: Int?
    @State private var day = 1

    var body: some View {
        NavigationStack {
            Form {
                if !model.templates.isEmpty {
                    Picker("Source", selection: $source) {
                        Text("New workout").tag(Source.new)
                        Text("From a template").tag(Source.template)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    switch source {
                    case .new:
                        TextField("Workout name", text: $name, prompt: Text("e.g. Upper A"))
                    case .template:
                        Picker("Template", selection: $templateID) {
                            Text("Choose a template").tag(Int?.none)
                            ForEach(model.templates) { template in
                                Text(verbatim: template.name).tag(Int?.some(template.id))
                            }
                        }
                    }
                    DayPicker(day: $day)
                } footer: {
                    if source == .template {
                        Text("The template's exercises are copied in; changing them later leaves the template alone.")
                    }
                }
                if let failure = model.failure {
                    Section {
                        StudioActionFailureNotice(failure: failure)
                    }
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Add workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.isSubmitting {
                        ProgressView()
                    } else {
                        Button("Add", action: add).disabled(!canAdd)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var canAdd: Bool {
        switch source {
        case .new: !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .template: templateID != nil
        }
    }

    private func add() {
        Task {
            switch source {
            case .new:
                if let workout = await model.addWorkout(
                    weekID: weekID, name: name.trimmingCharacters(in: .whitespaces), day: day
                ) {
                    dismiss()
                    openNewWorkout(workout)
                }
            case .template:
                guard let templateID else { return }
                if await model.applyTemplate(id: templateID, toWeek: weekID, day: day) {
                    dismiss()
                }
            }
        }
    }
}

/// Renames or moves a workout, or places a copy of it: the same week-and-day
/// question either way.
private struct WorkoutPlacementSheet: View {
    enum Mode {
        /// Rename, or move to another day of the same week.
        case edit
        /// Copy, exercises included, into any week and day.
        case duplicate
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let model: ProgramBuilderModel
    let source: WorkoutRef
    let weeks: [Week]

    @State private var name: String
    @State private var weekID: Int
    @State private var day: Int

    init(mode: Mode, model: ProgramBuilderModel, source: WorkoutRef, weeks: [Week]) {
        self.mode = mode
        self.model = model
        self.source = source
        self.weeks = weeks
        _name = State(initialValue: source.workout.name)
        _weekID = State(initialValue: source.weekID)
        _day = State(initialValue: source.workout.day)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    switch mode {
                    case .edit:
                        TextField("Workout name", text: $name)
                    case .duplicate:
                        Picker("Week", selection: $weekID) {
                            ForEach(weeks) { week in
                                Text("Week \(week.position)").tag(week.id)
                            }
                        }
                    }
                    DayPicker(day: $day)
                } footer: {
                    if mode == .duplicate {
                        Text("The copy keeps the workout's name and every exercise.")
                    }
                }
                if let failure = model.failure {
                    Section {
                        StudioActionFailureNotice(failure: failure)
                    }
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle(mode == .edit ? "Rename or move" : "Duplicate workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.isSubmitting {
                        ProgressView()
                    } else {
                        Button(mode == .edit ? "Save" : "Duplicate", action: confirm)
                            .disabled(mode == .edit && name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func confirm() {
        Task {
            let succeeded = switch mode {
            case .edit:
                await model.updateWorkout(
                    weekID: source.weekID, id: source.workout.id,
                    name: name.trimmingCharacters(in: .whitespaces), day: day
                )
            case .duplicate:
                await model.duplicateWorkout(weekID: source.weekID, id: source.workout.id, toWeek: weekID, day: day)
            }
            if succeeded {
                dismiss()
            }
        }
    }
}
