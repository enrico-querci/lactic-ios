import Foundation
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
    typealias Snapshot = TrainingHistory

    private(set) var state: Loadable<Snapshot> = .idle

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
            state = .loaded(
                Snapshot(
                    sessions: sessions.sorted {
                        ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast)
                    }
                )
            )
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
    typealias Detail = SessionSummary
    typealias ExerciseReference = SessionSummary.ExerciseReference

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

            // New servers carry display context directly. Keep one best-effort
            // workout fallback so history remains useful during a rolling API
            // deployment and for records created before the additive fields.
            let needsWorkoutFallback = session.workoutName == nil || session.exerciseLogs.contains {
                $0.exerciseID == nil || $0.exerciseName == nil || $0.position == nil
            }
            let workout: WorkoutDetail? = if needsWorkoutFallback {
                try? await client.send(ClientAPI.workout(id: session.workoutID))
            } else {
                nil
            }

            let workoutEntries = Dictionary(
                uniqueKeysWithValues: (workout?.workoutExercises ?? []).map { ($0.id, $0) }
            )
            let references = session.exerciseLogs.reduce(into: [Int: ExerciseReference]()) { result, log in
                let fallback = workoutEntries[log.workoutExerciseID]
                result[log.workoutExerciseID] = ExerciseReference(
                    exerciseID: log.exerciseID ?? fallback?.exercise.id,
                    name: log.exerciseName ?? fallback?.exercise.name,
                    position: log.position ?? fallback?.position
                )
            }

            state = .loaded(
                Detail(
                    session: session,
                    workoutName: session.workoutName ?? workout?.name,
                    exerciseReferences: references
                )
            )
        } catch {
            state = .failed((error as? APIError)?.message ?? error.localizedDescription)
        }
    }
}
