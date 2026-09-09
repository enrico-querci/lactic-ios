import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct ExerciseDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    let exerciseID: Int

    @State private var model: ExerciseDetailModel?

    var body: some View {
        Group {
            if let model {
                LoadableView(model) { detail in
                    content(detail, model: model)
                }
            }
        }
        .background(LacticColor.surface)
        .navigationTitle(model?.state.value?.exercise.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let model = model ?? ExerciseDetailModel(client: environment.client, exerciseID: exerciseID)
            self.model = model
            await model.load()
        }
    }

    private func content(_ detail: ExerciseDetailModel.Detail, model: ExerciseDetailModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LacticSpacing.xl) {
                ExerciseDemonstration(
                    cacheKey: "exercise-\(exerciseID)",
                    hasAnimation: detail.exercise.hasAnimation,
                    load: model.loadAnimation()
                )

                taxonomy(detail.exercise)

                if let description = detail.exercise.description, !description.isEmpty {
                    Text(description)
                        .font(.lacticBody)
                        .foregroundStyle(LacticColor.textSecondary)
                }

                if !detail.exercise.instructions.isEmpty {
                    instructions(detail.exercise.instructions)
                }

                history(detail.history)
            }
            .padding(LacticSpacing.lg)
        }
    }

    private func taxonomy(_ exercise: ExerciseDetail) -> some View {
        FlowLayout(spacing: LacticSpacing.xs) {
            if let primary = exercise.primaryMuscle {
                StatusBadge(primary.name, tone: .informative)
            }
            ForEach(exercise.secondaryMuscles, id: \.key) { muscle in
                StatusBadge(muscle.name)
            }
            ForEach(exercise.equipment, id: \.key) { item in
                StatusBadge(item.name)
            }
        }
    }

    private func instructions(_ steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text("How to do it")
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.textPrimary)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: LacticSpacing.sm) {
                    Text("\(index + 1).")
                        .font(.lacticCaption.monospacedDigit())
                        .foregroundStyle(LacticColor.textMuted)
                    Text(step)
                        .font(.lacticBody)
                        .foregroundStyle(LacticColor.textSecondary)
                }
            }
        }
    }

    private func history(_ sets: [SetLog]) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text("Your history")
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.textPrimary)

            if sets.isEmpty {
                Text("You have not logged this exercise yet.")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textMuted)
            } else {
                ForEach(sets) { set in
                    HStack {
                        Text("Set \(set.position)")
                            .font(.lacticCaption)
                            .foregroundStyle(LacticColor.textSecondary)
                        Spacer()
                        Text("\(Formatters.weight(set.weightKg, locale: environment.locale)) kg × \(set.reps)")
                            .font(.lacticNumeric)
                            .foregroundStyle(LacticColor.textPrimary)
                    }
                    .padding(.vertical, LacticSpacing.xs)
                }
            }
        }
    }
}
