import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: HomeModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadableView(model) { snapshot in
                        if snapshot.isEmpty {
                            HomeEmptyState()
                        } else {
                            HomeDashboard(snapshot: snapshot, locale: environment.locale)
                                .refreshable { await model.reload() }
                        }
                    }
                }
            }
            .background(LacticColor.surface)
            .navigationTitle(Text("Lactic"))
        }
        .task {
            let model = model ?? HomeModel(client: environment.client)
            self.model = model
            await model.load()
        }
    }
}
