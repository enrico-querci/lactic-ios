import LacticCore
import LacticKit
import LacticUI
import SwiftUI

struct ProgramsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: ProgramsModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    LoadableView(model) { assignments in
                        if assignments.isEmpty {
                            EmptyStateView(
                                title: String(localized: "No programmes yet"),
                                message: String(localized: "Your coach has not assigned one yet."),
                                systemImage: "list.bullet.rectangle"
                            )
                        } else {
                            ProgramsDashboard(assignments: assignments, locale: environment.locale)
                                .refreshable { await model.reload() }
                        }
                    }
                }
            }
            .background(LacticColor.surface)
            .navigationTitle(Text("Programmes"))
        }
        .task {
            let model = model ?? ProgramsModel(client: environment.client)
            self.model = model
            await model.load()
        }
    }
}
