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

        // swiftlint:disable:next multiple_closures_with_trailing_closure
        StudioColumns(
            depth: navigator.sessionID != nil ? 3 : navigator.clientID != nil ? 2 : 1,
            back: {
                if navigator.sessionID != nil {
                    navigator.sessionID = nil
                } else {
                    navigator.clientID = nil
                }
            }
        ) {
            StudioRosterList(model: roster, selection: $navigator.clientID)
        } second: {
            if let clientID = navigator.clientID {
                StudioClientDetailView(
                    client: client, clientID: clientID, roster: roster, selectedSession: $navigator.sessionID
                )
                // A new client is a new model: the view's `@State` would
                // otherwise keep showing the previous one.
                .id(clientID)
            } else {
                StudioSelectPrompt(
                    title: "Select a client",
                    message: "Their programmes and logged workouts appear here.",
                    systemImage: "person.2"
                )
            }
        } third: {
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
        .onChange(of: navigator.clientID) { navigator.sessionID = nil }
    }
}
