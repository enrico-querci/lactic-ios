import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// Programmes: the library, one programme's weeks and workouts beside it, and
/// the selected workout's exercises beside that. Building a programme is the
/// one task that goes two levels deep, and on a wide iPad all three are on
/// screen at once, so a change in the editor shows in the programme's volume
/// at once.
struct StudioProgrammesTab: View {
    @Environment(StudioNavigator.self) private var navigator

    let client: APIClient
    @State private var programmes: ProgramListModel
    @State private var templates: TemplateListModel
    /// Bumped when the workout editor changes a workout's volume, which the
    /// structure column summarises and has to re-read.
    @State private var volumeVersion = 0

    init(client: APIClient) {
        self.client = client
        _programmes = State(initialValue: ProgramListModel(client: client))
        _templates = State(initialValue: TemplateListModel(client: client))
    }

    var body: some View {
        @Bindable var navigator = navigator

        // swiftlint:disable:next multiple_closures_with_trailing_closure
        StudioColumns(
            depth: navigator.workout != nil ? 3 : navigator.programmeID != nil ? 2 : 1,
            back: {
                if navigator.workout != nil {
                    navigator.workout = nil
                } else {
                    navigator.programmeID = nil
                }
            }
        ) {
            StudioProgrammeList(programmes: programmes, templates: templates, selection: $navigator.programmeID)
        } second: {
            if let programmeID = navigator.programmeID {
                StudioProgramBuilderView(
                    client: client, programID: programmeID, selection: $navigator.workout,
                    volumeVersion: volumeVersion,
                    didChangeDetails: { Task { await programmes.load() } }
                )
                .id(programmeID)
            } else {
                StudioSelectPrompt(
                    title: "Select a programme",
                    message: "Its weeks and workouts appear here.",
                    systemImage: "list.bullet.rectangle"
                )
            }
        } third: {
            if let programmeID = navigator.programmeID, let workout = navigator.workout {
                StudioWorkoutEditorView(
                    client: client, programID: programmeID, weekID: workout.weekID, workoutID: workout.workoutID,
                    didChangeVolume: { volumeVersion += 1 }
                )
                .id(workout)
            } else {
                StudioSelectPrompt(
                    title: "Select a workout",
                    message: "Its exercises, sets and reps appear here.",
                    systemImage: "dumbbell"
                )
            }
        }
        .onChange(of: navigator.programmeID) { navigator.workout = nil }
    }
}

/// The programme library and the saved workout templates, in one list: a
/// template is only ever used from a programme's week, so it lives beside them.
struct StudioProgrammeList: View {
    let programmes: ProgramListModel
    let templates: TemplateListModel
    @Binding var selection: Int?

    @State private var isCreating = false
    @State private var pendingDeletion: Program?
    @State private var pendingTemplateDeletion: WorkoutTemplate?

    var body: some View {
        Group {
            if !programmes.hasLoaded, let failure = programmes.failure {
                StudioInitialFailureView(failure: failure, title: Text("Programmes")) {
                    Task { await programmes.load() }
                }
            } else if !programmes.hasLoaded {
                LoadingView(String(localized: "Loading programmes"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LacticColor.surface)
            } else {
                list
            }
        }
        .navigationTitle("Programmes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreating = true
                } label: {
                    Label("New programme", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            ProgramDetailsSheet(
                title: "New programme",
                saveTitle: "Create",
                name: "",
                description: ""
            ) { name, description in
                guard let program = await programmes.create(name: name, description: description) else {
                    return programmes.failure
                }
                // An empty programme is only a starting point: open it.
                selection = program.id
                return nil
            }
        }
        .confirmationDialog(
            "Delete \(pendingDeletion?.name ?? "")?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: {
                if !$0 {
                    pendingDeletion = nil
                }
            }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { program in
            Button("Delete programme", role: .destructive) {
                Task {
                    if await programmes.delete(id: program.id), selection == program.id {
                        selection = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its assignments, and the workouts clients logged against them, are deleted too.")
        }
        .confirmationDialog(
            "Delete \(pendingTemplateDeletion?.name ?? "")?",
            isPresented: Binding(get: { pendingTemplateDeletion != nil }, set: {
                if !$0 {
                    pendingTemplateDeletion = nil
                }
            }),
            titleVisibility: .visible,
            presenting: pendingTemplateDeletion
        ) { template in
            Button("Delete template", role: .destructive) {
                Task { await templates.delete(id: template.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Workouts already made from it are not affected.")
        }
        .task {
            async let programmeLoad: Void = programmes.load()
            async let templateLoad: Void = templates.load()
            await programmeLoad
            await templateLoad
        }
    }

    private var list: some View {
        List(selection: $selection) {
            if let failure = programmes.failure {
                StudioActionFailureNotice(failure: failure)
                    .studioPlainRow()
            }

            Section {
                if programmes.programs.isEmpty {
                    StudioEmptyCard(
                        title: "No programmes yet",
                        message: "Create your first programme, then add weeks and workouts.",
                        systemImage: "list.bullet.rectangle"
                    ) {
                        Button("New programme") { isCreating = true }
                            .lacticButton()
                            .frame(maxWidth: 280)
                    }
                    .studioPlainRow()
                } else {
                    ForEach(programmes.programs) { program in
                        ProgramRow(program: program)
                            .tag(program.id)
                            .studioListRow(isSelected: selection == program.id)
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = program
                                }
                            }
                            .contextMenu {
                                Button("Delete programme", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = program
                                }
                            }
                    }
                }
            } header: {
                StudioSectionHeader("Programmes")
            }

            Section {
                if templates.templates.isEmpty {
                    Text("In a programme, open a workout's menu and choose Save as template.")
                        .font(.lacticCaption)
                        .foregroundStyle(LacticColor.textSecondary)
                        .studioPlainRow()
                } else {
                    ForEach(templates.templates) { template in
                        TemplateRow(template: template) { pendingTemplateDeletion = template }
                            .selectionDisabled()
                            .studioListRow()
                    }
                }
            } header: {
                StudioSectionHeader("Workout templates")
            }
        }
        .studioListColumn()
        .refreshable {
            await programmes.load()
            await templates.load()
        }
    }
}

private struct ProgramRow: View {
    @Environment(StudioEnvironment.self) private var environment
    let program: Program

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text(verbatim: program.name)
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.textPrimary)
            if let description = program.description, !description.isEmpty {
                Text(verbatim: description)
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textSecondary)
                    .lineLimit(2)
            }
            Text("Created \(Formatters.date(program.createdAt, locale: environment.locale))")
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A saved workout. Not selectable: there is nothing to open, only to delete.
private struct TemplateRow: View {
    @Environment(StudioEnvironment.self) private var environment
    let template: WorkoutTemplate
    let delete: () -> Void

    var body: some View {
        HStack(spacing: LacticSpacing.md) {
            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text(verbatim: template.name)
                    .font(.lacticHeadline)
                    .foregroundStyle(LacticColor.textPrimary)
                Text("Saved \(Formatters.date(template.createdAt, locale: environment.locale))")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button("Delete template", systemImage: "trash", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(width: LacticSize.minimumHitTarget, height: LacticSize.minimumHitTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Template actions"))
        }
        .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
        }
    }
}

/// A programme's name and description — for creating one and for editing it.
///
/// `save` returns the failure to show, or `nil` once it worked.
struct ProgramDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: LocalizedStringKey
    let saveTitle: LocalizedStringKey
    @State var name: String
    @State var description: String
    let save: (String, String) async -> CoachActionFailure?

    @State private var isSaving = false
    @State private var failure: CoachActionFailure?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("e.g. Push Pull Legs"))
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2 ... 6)
                }
                if let failure {
                    Section {
                        StudioActionFailureNotice(failure: failure)
                    }
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(saveTitle) {
                            Task {
                                isSaving = true
                                failure = await save(name.trimmingCharacters(in: .whitespaces), description)
                                isSaving = false
                                if failure == nil {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
