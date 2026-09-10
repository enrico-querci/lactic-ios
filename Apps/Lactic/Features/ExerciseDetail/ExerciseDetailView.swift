import LacticUI
import SwiftUI

struct ExerciseDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    let exerciseID: Int

    @State private var model: ExerciseDetailModel?

    var body: some View {
        LoadableView(model) { detail in
            if let model {
                ExerciseProgressView(
                    detail: detail,
                    locale: environment.locale,
                    cacheKey: "exercise-\(exerciseID)",
                    animationLoader: model.loadAnimation()
                )
                .refreshable { await model.reload() }
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
}
