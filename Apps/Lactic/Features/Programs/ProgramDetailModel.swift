import LacticKit
import LacticUI
import Observation

/// One programme's weeks and workouts.
///
/// Takes the **programme** id, not the assignment id — the endpoint is keyed
/// that way. Its response also carries a top-level `assignment_id`, which is
/// the only place a client can learn it: `WorkoutSessionBlueprint` never
/// serializes `program_assignment_id`, yet starting a session requires it.
@MainActor
@Observable
final class ProgramDetailModel: LoadableSource {
    private(set) var state: Loadable<ProgramDetail> = .idle

    private let client: APIClient
    private let programID: Int

    init(client: APIClient, programID: Int) {
        self.client = client
        self.programID = programID
    }

    func load() async {
        if case .loaded = state {
            return
        }
        await reload()
    }

    func reload() async {
        state = .loading
        do {
            let detail: ProgramDetail = try await client.send(ClientAPI.program(id: programID))
            state = .loaded(detail)
        } catch {
            state = .failed((error as? APIError)?.message ?? error.localizedDescription)
        }
    }
}
