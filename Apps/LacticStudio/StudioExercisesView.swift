import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// Exercises: the catalog on one side, the selected exercise on the other.
struct StudioExercisesTab: View {
    @Environment(StudioNavigator.self) private var navigator

    let client: APIClient
    @State private var model: ExerciseCatalogModel

    init(client: APIClient) {
        self.client = client
        _model = State(initialValue: ExerciseCatalogModel(client: client))
    }

    var body: some View {
        @Bindable var navigator = navigator

        NavigationSplitView {
            StudioExercisesView(model: model, selection: $navigator.exerciseID)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
        } detail: {
            if let exerciseID = navigator.exerciseID {
                StudioExerciseDetailView(client: client, exerciseID: exerciseID)
                    .id(exerciseID)
            } else {
                StudioSelectPrompt(
                    title: "Select an exercise",
                    message: "Its demonstration, muscles and instructions appear here.",
                    systemImage: "dumbbell"
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

/// The exercise catalog, plus the coach's own exercises — the web's Exercises
/// page.
struct StudioExercisesView: View {
    let model: ExerciseCatalogModel
    @Binding var selection: Int?

    @State private var isCreating = false
    @State private var pendingDeletion: Exercise?

    var body: some View {
        @Bindable var model = model

        List(selection: $selection) {
            Section {
                if let failure = model.failure {
                    StudioActionFailureNotice(failure: failure)
                        .studioPlainRow()
                }
                ForEach(model.exercises) { exercise in
                    ExerciseRow(exercise: exercise)
                        .tag(exercise.id)
                        .studioListRow(isSelected: selection == exercise.id)
                        .swipeActions {
                            if exercise.isCustom {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = exercise
                                }
                            }
                        }
                        .contextMenu {
                            if exercise.isCustom {
                                Button("Delete exercise", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = exercise
                                }
                            }
                        }
                        .onAppear {
                            if exercise.id == model.exercises.last?.id {
                                Task { await model.loadMore() }
                            }
                        }
                }
                if model.isLoadingMore || (model.isLoading && model.exercises.isEmpty) {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .studioPlainRow()
                } else if model.hasLoaded, model.exercises.isEmpty {
                    Text("No exercises match these filters.")
                        .foregroundStyle(LacticColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .studioPlainRow()
                }
            } header: {
                if model.hasLoaded {
                    StudioSectionHeader("\(model.totalCount) exercises")
                }
            }
        }
        .studioListColumn()
        .searchable(text: $model.filter.search, prompt: Text("Search exercises"))
        .navigationTitle("Exercises")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ExerciseFilterMenu(model: model, showsAllFilters: true)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreating = true
                } label: {
                    Label("New exercise", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            CustomExerciseSheet(model: model)
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
        ) { exercise in
            Button("Delete exercise", role: .destructive) {
                Task {
                    if await model.deleteCustom(id: exercise.id), selection == exercise.id {
                        selection = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It is removed from every workout that uses it, along with the sets clients logged for it.")
        }
        .task(id: model.filter) {
            if model.hasLoaded {
                // Debounced, so typing a word is one request, not one per
                // keystroke.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await model.reload()
            } else {
                await model.load()
            }
        }
        .refreshable { await model.reload() }
    }
}

/// A coach's own exercise: a name and the muscle group it trains, with an
/// optional video to show clients.
private struct CustomExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss

    let model: ExerciseCatalogModel
    @State private var name = ""
    @State private var muscleGroup = CustomMuscleGroup.chest
    @State private var videoURL = ""
    @State private var thumbnailURL = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("e.g. Tempo goblet squat"))
                    Picker("Muscle group", selection: $muscleGroup) {
                        ForEach(CustomMuscleGroup.allCases) { group in
                            Text(verbatim: group.label).tag(group)
                        }
                    }
                }
                Section {
                    TextField("Video URL", text: $videoURL, prompt: Text(verbatim: "https://"))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Thumbnail URL", text: $thumbnailURL, prompt: Text(verbatim: "https://"))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Media (optional)")
                } footer: {
                    Text("Only you see your own exercises, in the catalog and when building workouts.")
                }
                if let failure = model.failure {
                    Section {
                        StudioActionFailureNotice(failure: failure)
                    }
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("New exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.isSubmitting {
                        ProgressView()
                    } else {
                        Button("Create", action: create)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func create() {
        Task {
            if await model.createCustom(
                name: name, muscleGroup: muscleGroup, videoURL: videoURL, thumbnailURL: thumbnailURL
            ) {
                dismiss()
            }
        }
    }
}

/// One exercise in full: its demonstration, description, muscles, equipment,
/// level and step-by-step instructions.
struct StudioExerciseDetailView: View {
    @State private var model: ExerciseDetailModel

    init(client: APIClient, exerciseID: Int) {
        _model = State(initialValue: ExerciseDetailModel(client: client, exerciseID: exerciseID))
    }

    var body: some View {
        Group {
            if let detail = model.detail {
                content(detail)
            } else if let failure = model.failure {
                StudioInitialFailureView(failure: failure, title: Text("Exercise")) {
                    Task { await model.load() }
                }
            } else {
                LoadingView(String(localized: "Loading exercise"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LacticColor.surface)
            }
        }
        .navigationTitle(model.detail?.name ?? String(localized: "Exercise"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    private func content(_ detail: ExerciseDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LacticSpacing.xl) {
                VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                    if detail.exercise.isCustom {
                        StatusBadge(String(localized: "Custom"), tone: .informative)
                    }
                    Text(verbatim: detail.name)
                        .font(.lacticDisplay)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Mounted only here, and only on request: each fetch costs one
                // request against the provider's quota.
                ExerciseDemonstration(
                    cacheKey: "exercise-\(detail.id)", hasAnimation: detail.hasAnimation,
                    load: model.animationLoader()
                )

                if let description = detail.description, !description.isEmpty {
                    Text(verbatim: description)
                        .font(.lacticBody)
                        .foregroundStyle(LacticColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                facts(detail)

                if !detail.instructions.isEmpty {
                    VStack(alignment: .leading, spacing: LacticSpacing.md) {
                        Text("Instructions")
                            .font(.lacticTitle)
                        ForEach(Array(detail.instructions.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: LacticSpacing.md) {
                                Text(verbatim: "\(index + 1)")
                                    .font(.lacticCaption.weight(.bold))
                                    .foregroundStyle(LacticColor.textOnAccent)
                                    .frame(width: 24, height: 24)
                                    .background(LacticColor.accent, in: Circle())
                                Text(verbatim: step)
                                    .font(.lacticBody)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if let video = detail.exercise.videoURL.flatMap(URL.init(string:)) {
                    Link(destination: video) {
                        Label("Watch video", systemImage: "play.rectangle.fill")
                    }
                    .lacticButton(.secondary)
                }
            }
            .padding(LacticSpacing.xl)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(LacticColor.surface)
    }

    private func facts(_ detail: ExerciseDetail) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            fact("Primary muscle", detail.exercise.muscleLabel)
            if !detail.secondaryMuscles.isEmpty {
                fact("Secondary muscles", detail.secondaryMuscles.map(\.name).joined(separator: ", "))
            }
            if !detail.equipment.isEmpty {
                fact("Equipment", detail.equipment.map(\.name).joined(separator: ", "))
            }
            if let category = detail.exercise.category {
                fact("Category", ExerciseVocabulary.category(category))
            }
            if let difficulty = detail.exercise.difficulty {
                fact("Level", ExerciseVocabulary.difficulty(difficulty))
            }
        }
        .studioCard()
    }

    private func fact(_ label: LocalizedStringKey, _ value: String) -> some View {
        LabeledContent {
            Text(verbatim: value)
                .multilineTextAlignment(.trailing)
        } label: {
            Text(label)
                .foregroundStyle(LacticColor.textSecondary)
        }
        .font(.lacticBody)
    }
}
