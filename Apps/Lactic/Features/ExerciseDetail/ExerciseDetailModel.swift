import Foundation
import LacticKit
import LacticUI
import Observation

/// One exercise: the coach's reference material plus the client's own history.
@MainActor
@Observable
final class ExerciseDetailModel: LoadableSource {
    struct Detail: Sendable, Equatable {
        let exercise: ExerciseDetail
        /// Flat and ungroupable by design: the endpoint returns sets ordered
        /// newest session first, with no dates and no session reference, so
        /// they cannot be split into sessions here.
        let history: [SetLog]
    }

    private(set) var state: Loadable<Detail> = .idle

    private let client: APIClient
    private let exerciseID: Int

    init(client: APIClient, exerciseID: Int) {
        self.client = client
        self.exerciseID = exerciseID
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
            async let exerciseTask: ExerciseDetail = client.send(ClientAPI.exercise(id: exerciseID))
            async let historyTask: [SetLog] = client.send(ClientAPI.exerciseHistory(id: exerciseID))
            let (exercise, history) = try await (exerciseTask, historyTask)
            state = .loaded(Detail(exercise: exercise, history: history))
        } catch {
            state = .failed((error as? APIError)?.message ?? error.localizedDescription)
        }
    }

    /// Fetches the demonstration's bytes. Authenticated and metered, so this is
    /// only ever called when the user opens the demonstration.
    func loadAnimation() -> @Sendable () async throws -> Data {
        let client = client
        let id = exerciseID
        return { try await client.data(for: ClientAPI.animation(exerciseID: id)) }
    }
}
