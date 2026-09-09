import LacticKit
import LacticUI
import Observation

/// Completed and in-progress sessions.
///
/// The API returns these ordered by `started_at` descending, but sorting again
/// locally costs nothing and means the screen does not silently depend on an
/// ordering the endpoint has never promised in writing.
@MainActor
@Observable
final class HistoryModel: LoadableSource {
    private(set) var state: Loadable<[WorkoutSession]> = .idle

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
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
            let sessions: [WorkoutSession] = try await client.send(ClientAPI.workoutSessions)
            state = .loaded(sessions.sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) })
        } catch {
            state = .failed((error as? APIError)?.message ?? error.localizedDescription)
        }
    }
}

/// One session with its logged sets.
///
/// Also fetches the workout, which the session payload does not include. The
/// web renders `Exercise #<id>` here because it never does that second fetch —
/// a raw database id shown to a gym client. One extra request resolves every
/// exercise name.
@MainActor
@Observable
final class SessionDetailModel: LoadableSource {
    struct Detail: Sendable, Equatable {
        let session: WorkoutSessionDetail
        /// Exercise name by workout-exercise id, when the workout could be read.
        let exerciseNames: [Int: String]
        let positions: [Int: String]
    }

    private(set) var state: Loadable<Detail> = .idle

    private let client: APIClient
    private let sessionID: Int

    init(client: APIClient, sessionID: Int) {
        self.client = client
        self.sessionID = sessionID
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
            let session: WorkoutSessionDetail = try await client.send(ClientAPI.workoutSession(id: sessionID))

            // Best effort: a workout can be unreachable if the coach removed it,
            // and history should still render rather than fail wholesale.
            var names: [Int: String] = [:]
            var positions: [Int: String] = [:]
            if let workout: WorkoutDetail = try? await client.send(ClientAPI.workout(id: session.workoutID)) {
                for entry in workout.workoutExercises {
                    names[entry.id] = entry.exercise.name
                    positions[entry.id] = entry.position
                }
            }

            state = .loaded(Detail(session: session, exerciseNames: names, positions: positions))
        } catch {
            state = .failed((error as? APIError)?.message ?? error.localizedDescription)
        }
    }
}
