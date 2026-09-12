import Foundation
import LacticKit
import LacticUI
import Observation

/// What the client needs on opening the app.
///
/// Mirrors the web's home: resuming an unfinished session outranks starting
/// something new, then the current programme and what is next in it, then
/// recent activity.
@MainActor
@Observable
final class HomeModel: LoadableSource {
    typealias Snapshot = HomeSnapshot

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
            // Independent requests, so issue them together rather than in
            // sequence — the web does these serially and pays for it on a cold
            // start over gym wifi.
            async let assignmentsTask: [ProgramAssignment] = client.send(ClientAPI.programs)
            async let sessionsTask: [WorkoutSession] = client.send(ClientAPI.workoutSessions)
            let (assignments, sessions) = try await (assignmentsTask, sessionsTask)

            // `GET /client/programs` is already filtered to active assignments
            // server-side, so the first is the current one.
            let assignment = assignments.first
            var program: ProgramDetail?
            if let assignment {
                program = try? await client.send(ClientAPI.program(id: assignment.program.id))
            }

            var snapshot = Snapshot(
                assignment: assignment,
                program: program,
                featuredExerciseCount: nil,
                featuredTargetSets: nil,
                sessions: sessions
            )
            let featuredWorkoutID = snapshot.resumable?.workoutID ?? snapshot.upNext?.workout.id
            if let featuredWorkoutID {
                if let detail: WorkoutDetail = try? await client.send(ClientAPI.workout(id: featuredWorkoutID)) {
                    snapshot.featuredExerciseCount = detail.workoutExercises.count
                    snapshot.featuredTargetSets = detail.workoutExercises.reduce(0) { $0 + $1.sets }
                }
            }

            state = .loaded(snapshot)
        } catch {
            state = .failed((error as? APIError)?.message ?? error.localizedDescription)
        }
    }
}
