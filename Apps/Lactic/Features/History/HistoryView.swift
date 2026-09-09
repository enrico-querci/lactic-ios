import LacticUI
import SwiftUI

struct HistoryView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: HistoryModel?

    var body: some View {
        NavigationStack {
            LoadableView(model) { snapshot in
                if snapshot.sessions.isEmpty {
                    EmptyStateView(
                        title: String(localized: "No workouts logged yet"),
                        message: String(localized: "Sessions you complete will appear here."),
                        systemImage: "clock.arrow.circlepath"
                    )
                } else if let model {
                    HistoryDashboard(snapshot: snapshot, locale: environment.locale)
                        .refreshable { await model.reload() }
                }
            }
            .background(LacticColor.surface)
            .navigationTitle(Text("History"))
        }
        .task {
            let model = model ?? HistoryModel(client: environment.client)
            self.model = model
            await model.load()
        }
    }
}

struct SessionDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    let sessionID: Int

    @State private var model: SessionDetailModel?

    var body: some View {
        LoadableView(model) { detail in
            if let model {
                SessionSummaryView(detail: detail, locale: environment.locale)
                    .refreshable { await model.reload() }
            }
        }
        .background(LacticColor.surface)
        .navigationTitle(model?.state.value?.workoutName ?? String(localized: "Session"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let model = model ?? SessionDetailModel(client: environment.client, sessionID: sessionID)
            self.model = model
            await model.load()
        }
    }
}
