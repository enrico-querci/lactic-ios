import Foundation
import LacticCore

/// How far a client is through one assigned programme.
///
/// Progress is derived by intersecting the programme's own workout ids with
/// the ids the client has sessions for, rather than counting sessions. A
/// client can log a workout that belongs to another programme, and a workout
/// can be performed more than once; both would inflate a naive count.
public struct ProgrammeProgress: Sendable, Equatable {
    public let program: ProgramDetail
    public let sessions: [WorkoutSession]

    public init(program: ProgramDetail, sessions: [WorkoutSession]) {
        self.program = program
        self.sessions = sessions
    }

    public enum WorkoutStatus: Sendable, Equatable {
        case completed
        case inProgress
        case upcoming
    }

    public var totalWorkoutCount: Int {
        program.weeks.reduce(0) { $0 + $1.workouts.count }
    }

    public var completedWorkoutCount: Int {
        programmeWorkoutIDs.intersection(completedWorkoutIDs).count
    }

    public var inProgressWorkoutIDs: Set<Int> {
        Set(sessions.filter(\.isInProgress).map(\.workoutID))
    }

    public var completedWorkoutIDs: Set<Int> {
        Set(sessions.filter { !$0.isInProgress }.map(\.workoutID))
    }

    public func progress(in week: Week) -> (completed: Int, total: Int) {
        let workoutIDs = Set(week.workouts.map(\.id))
        return (workoutIDs.intersection(completedWorkoutIDs).count, workoutIDs.count)
    }

    /// In progress outranks completed: a workout performed before and started
    /// again now is something the client can resume, and that is the more
    /// useful thing to say about it.
    public func status(for workoutID: Int) -> WorkoutStatus {
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
}
