import Foundation
import LacticKit
import LacticUI
import Observation

/// One exercise: the coach's reference material plus the client's own history.
@MainActor
@Observable
final class ExerciseDetailModel: LoadableSource {
    /// The derivations live in `LacticKit` so both the arithmetic and its
    /// tests sit with the models they read, leaving this type to fetching and
    /// state. The names views already use are kept.
    typealias Detail = ExerciseProgress
    typealias HistorySession = ExerciseProgress.Session

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
