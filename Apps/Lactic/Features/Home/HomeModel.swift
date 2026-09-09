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
    struct Snapshot: Sendable, Equatable {
        var assignment: ProgramAssignment?
        var program: ProgramDetail?
        var featuredExerciseCount: Int?
        var featuredTargetSets: Int?
        var sessions: [WorkoutSession]

        /// An unfinished session, if there is one. Resuming beats starting.
        var resumable: WorkoutSession? {
            sessions
                .filter(\.isInProgress)
                .max { ($0.startedAt ?? .distantPast) < ($1.startedAt ?? .distantPast) }
        }

        /// The first workout in programme order that has no completed session.
        ///
        /// Ordered by week position then day, matching how a client reads a
        /// programme rather than by id.
        var upNext: (week: Week, workout: Workout)? {
            guard let program else { return nil }
            let completed = Set(sessions.filter { !$0.isInProgress }.map(\.workoutID))
            for week in program.orderedWeeks {
                for workout in week.orderedWorkouts where !completed.contains(workout.id) {
                    return (week, workout)
                }
            }
            return nil
        }

        var recent: [WorkoutSession] {
            Array(
                sessions
                    .filter { !$0.isInProgress }
                    .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
                    .prefix(3)
            )
        }

        var completedWorkoutCount: Int {
            guard let program else { return 0 }
            let programmeWorkoutIDs = Set(program.weeks.flatMap(\.workouts).map(\.id))
            let completed = Set(sessions.filter { !$0.isInProgress }.map(\.workoutID))
            return programmeWorkoutIDs.intersection(completed).count
        }

        var totalWorkoutCount: Int {
            program?.weeks.reduce(0) { $0 + $1.workouts.count } ?? 0
        }

        func workoutName(for workoutID: Int) -> String? {
            program?.weeks.flatMap(\.workouts).first { $0.id == workoutID }?.name
        }

        var isEmpty: Bool {
            assignment == nil && sessions.isEmpty
        }
    }

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
