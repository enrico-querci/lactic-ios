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
    struct Snapshot: Sendable, Equatable {
        let program: ProgramDetail
        let sessions: [WorkoutSession]

        var totalWorkoutCount: Int {
            program.weeks.reduce(0) { $0 + $1.workouts.count }
        }

        var completedWorkoutCount: Int {
            programmeWorkoutIDs.intersection(completedWorkoutIDs).count
        }

        var inProgressWorkoutIDs: Set<Int> {
            Set(sessions.filter(\.isInProgress).map(\.workoutID))
        }

        func progress(in week: Week) -> (completed: Int, total: Int) {
            let workoutIDs = Set(week.workouts.map(\.id))
            return (workoutIDs.intersection(completedWorkoutIDs).count, workoutIDs.count)
        }

        func status(for workoutID: Int) -> WorkoutStatus {
            if sessions.contains(where: { $0.workoutID == workoutID && $0.isInProgress }) {
                return .inProgress
            }
            if completedWorkoutIDs.contains(workoutID) {
                return .completed
            }
            return .upcoming
        }

        private var programmeWorkoutIDs: Set<Int> {
            Set(program.weeks.flatMap(\.workouts).map(\.id))
        }

        var completedWorkoutIDs: Set<Int> {
            Set(sessions.filter { !$0.isInProgress }.map(\.workoutID))
        }
    }

    enum WorkoutStatus: Sendable, Equatable {
        case completed
        case inProgress
        case upcoming
    }

    private(set) var state: Loadable<Snapshot> = .idle

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
            async let programTask: ProgramDetail = client.send(ClientAPI.program(id: programID))
            async let sessionsTask: [WorkoutSession] = client.send(ClientAPI.workoutSessions)
            let (program, sessions) = try await (programTask, sessionsTask)
            state = .loaded(Snapshot(program: program, sessions: sessions))
        } catch {
            state = .failed((error as? APIError)?.message ?? error.localizedDescription)
        }
    }
}
