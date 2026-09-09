import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct ProgramDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    let programID: Int

    @State private var model: ProgramDetailModel?

    var body: some View {
        LoadableView(model) { snapshot in
            ProgramPlanView(snapshot: snapshot, locale: environment.locale)
                .refreshable { await model?.reload() }
        }
        .background(LacticColor.surface)
        .navigationTitle(model?.state.value?.program.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let model = model ?? ProgramDetailModel(client: environment.client, programID: programID)
            self.model = model
            await model.load()
        }
    }
}
