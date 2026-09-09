import LacticKit
import LacticUI
import Observation

/// The client's assigned programmes.
///
/// `GET /client/programs` returns **active assignments only** — the API filters
/// server-side, so paused and completed ones never arrive and the screen must
/// not imply it is showing everything.
@MainActor
@Observable
final class ProgramsModel: LoadableSource {
    private(set) var state: Loadable<[ProgramAssignment]> = .idle

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func load() async {
        if case .loaded = state {
            return
        } // Already have it; refresh is explicit.
        await reload()
    }

    func reload() async {
        state = .loading
        do {
            let assignments: [ProgramAssignment] = try await client.send(ClientAPI.programs)
            state = .loaded(assignments)
        } catch {
            state = .failed((error as? APIError)?.message ?? error.localizedDescription)
        }
    }
}
