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
        var sessions: [WorkoutSession]

        /// An unfinished session, if there is one. Resuming beats starting.
        var resumable: WorkoutSession? {
            sessions.first { $0.isInProgress }
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
            Array(sessions.sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }.prefix(3))
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

            state = .loaded(Snapshot(assignment: assignment, program: program, sessions: sessions))
        } catch {
            state = .failed((error as? APIError)?.message ?? error.localizedDescription)
        }
    }
}
