import LacticCore
import LacticKit
import LacticUI
import SwiftUI

// The exercise catalog's building blocks: the picker the workout editor adds
// from, the row and filters it shares with the Exercises destination, and the
// vocabulary the app translates itself.

/// Picks an exercise from the catalog. Lists only what can actually go into
/// a workout, so nothing offered here is refused by the builder.
struct StudioExercisePicker: View {
    @Environment(\.dismiss) private var dismiss

    @State private var model: ExerciseCatalogModel
    private let pick: (Exercise) async -> Bool

    init(client: APIClient, pick: @escaping (Exercise) async -> Bool) {
        _model = State(initialValue: ExerciseCatalogModel(client: client, perPage: 20))
        self.pick = pick
    }

    var body: some View {
        NavigationStack {
            List {
                if let failure = model.failure {
                    StudioActionFailureNotice(failure: failure)
                        .listRowInsets(EdgeInsets())
                }
                ForEach(model.exercises) { exercise in
                    Button {
                        Task {
                            if await pick(exercise) {
                                dismiss()
                            }
                        }
                    } label: {
                        ExerciseRow(exercise: exercise)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if exercise.id == model.exercises.last?.id {
                            Task { await model.loadMore() }
                        }
                    }
                }
                if model.isLoadingMore || (model.isLoading && model.exercises.isEmpty) {
                    ProgressView().frame(maxWidth: .infinity)
                } else if model.hasLoaded, model.exercises.isEmpty {
                    Text("No exercises found")
                        .foregroundStyle(LacticColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .listStyle(.plain)
            .searchable(text: $model.filter.search, prompt: Text("Search exercises"))
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ExerciseFilterMenu(model: model, showsAllFilters: false)
                }
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
        }
    }
}

/// One catalog row: name, muscle, and whether the coach made it.
struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: LacticSpacing.md) {
            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text(verbatim: exercise.name)
                    .font(.lacticBody.weight(.medium))
                    .foregroundStyle(LacticColor.textPrimary)
                Text(verbatim: [exercise.muscleLabel, exercise.equipment.map(\.name).joined(separator: ", ")]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if exercise.isCustom {
                StatusBadge(String(localized: "Custom"), tone: .informative)
            }
        }
        .padding(.vertical, LacticSpacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// The catalog filters, from the server's own taxonomy. The picker offers
/// muscle and equipment; the catalog screen adds category, level and owner.
struct ExerciseFilterMenu: View {
    @Bindable var model: ExerciseCatalogModel
    let showsAllFilters: Bool

    var body: some View {
        Menu {
            if let taxonomy = model.taxonomy {
                Picker("Muscle", selection: $model.filter.muscle) {
                    Text("All muscles").tag(String?.none)
                    ForEach(taxonomy.muscles, id: \.key) { muscle in
                        Text(verbatim: muscle.name).tag(String?.some(muscle.key))
                    }
                }
                .pickerStyle(.menu)
                Picker("Equipment", selection: $model.filter.equipment) {
                    Text("All equipment").tag(String?.none)
                    ForEach(taxonomy.equipment, id: \.key) { item in
                        Text(verbatim: item.name).tag(String?.some(item.key))
                    }
                }
                .pickerStyle(.menu)
                if showsAllFilters {
                    Picker("Category", selection: $model.filter.category) {
                        Text("All categories").tag(String?.none)
                        ForEach(taxonomy.categories, id: \.self) { category in
                            Text(verbatim: ExerciseVocabulary.category(category)).tag(String?.some(category))
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("Level", selection: $model.filter.difficulty) {
                        Text("All levels").tag(String?.none)
                        ForEach(taxonomy.difficulties, id: \.self) { level in
                            Text(verbatim: ExerciseVocabulary.difficulty(level)).tag(String?.some(level))
                        }
                    }
                    .pickerStyle(.menu)
                }
            } else {
                Text("Filters are unavailable right now")
            }
            if showsAllFilters {
                Picker("Show", selection: $model.filter.ownership) {
                    Text("Catalog and custom").tag(ExerciseFilter.Ownership.all)
                    Text("Catalog only").tag(ExerciseFilter.Ownership.catalog)
                    Text("My exercises only").tag(ExerciseFilter.Ownership.mine)
                }
                .pickerStyle(.menu)
            }
            if model.filter.isActive {
                Button("Clear filters", systemImage: "xmark.circle", role: .destructive) {
                    model.filter = ExerciseFilter()
                }
            }
        } label: {
            Label(
                "Filters",
                systemImage: model.filter.isActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
    }
}

/// Category and level are a small closed vocabulary the app translates;
/// muscles and equipment arrive already localized by the API.
enum ExerciseVocabulary {
    static func category(_ value: String) -> String {
        switch value {
        case "strength": String(localized: "Strength")
        case "cardio": String(localized: "Cardio")
        case "balance": String(localized: "Balance")
        case "flexibility": String(localized: "Flexibility")
        case "stretching": String(localized: "Stretching")
        case "plyometrics": String(localized: "Plyometrics")
        case "powerlifting": String(localized: "Powerlifting")
        case "olympic weightlifting": String(localized: "Olympic weightlifting")
        default: value.capitalized
        }
    }

    static func difficulty(_ value: String) -> String {
        switch value {
        case "beginner": String(localized: "Beginner")
        case "intermediate": String(localized: "Intermediate")
        case "advanced": String(localized: "Advanced")
        default: value.capitalized
        }
    }
}
