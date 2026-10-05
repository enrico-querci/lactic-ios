import LacticKit
import LacticUI
import SwiftUI

/// Clients: the roster, the selected client beside it, and one of that
/// client's logged sessions beside that — three columns on iPad, a stack of
/// pushes on iPhone.
struct StudioClientsTab: View {
    @Environment(StudioNavigator.self) private var navigator

    let client: APIClient
    let roster: ClientListModel

    var body: some View {
        @Bindable var navigator = navigator

        NavigationSplitView {
            StudioRosterList(model: roster, selection: $navigator.clientID)
                .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 400)
        } content: {
            if let clientID = navigator.clientID {
                StudioClientDetailView(
                    client: client, clientID: clientID, roster: roster, selectedSession: $navigator.sessionID
                )
                // A new client is a new model: the view's `@State` would
                // otherwise keep showing the previous one.
                .id(clientID)
                .navigationSplitViewColumnWidth(min: 340, ideal: 400, max: 480)
            } else {
                StudioSelectPrompt(
                    title: "Select a client",
                    message: "Their programmes and logged workouts appear here.",
                    systemImage: "person.2"
                )
            }
        } detail: {
            if let clientID = navigator.clientID, let sessionID = navigator.sessionID {
                StudioClientSessionView(client: client, clientID: clientID, sessionID: sessionID)
                    .id(sessionID)
            } else {
                StudioSelectPrompt(
                    title: "Select a workout",
                    message: "Every exercise and set the client logged appears here.",
                    systemImage: "figure.strengthtraining.traditional"
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: navigator.clientID) { navigator.sessionID = nil }
    }
}
