import Foundation
import LacticCore

/// What the client needs on opening the app.
///
/// Resuming an unfinished session outranks starting something new, then the
/// current programme and what is next in it, then recent activity.
public struct HomeSnapshot: Sendable, Equatable {
    public var assignment: ProgramAssignment?
    public var program: ProgramDetail?
    public var featuredExerciseCount: Int?
    public var featuredTargetSets: Int?
    public var sessions: [WorkoutSession]

    public init(
        assignment: ProgramAssignment? = nil,
        program: ProgramDetail? = nil,
        featuredExerciseCount: Int? = nil,
        featuredTargetSets: Int? = nil,
        sessions: [WorkoutSession] = []
    ) {
        self.assignment = assignment
        self.program = program
        self.featuredExerciseCount = featuredExerciseCount
        self.featuredTargetSets = featuredTargetSets
        self.sessions = sessions
    }

    /// The newest unfinished session, if there is one. Resuming beats starting.
    public var resumable: WorkoutSession? {
        sessions
            .filter(\.isInProgress)
            .max { ($0.startedAt ?? .distantPast) < ($1.startedAt ?? .distantPast) }
    }

    /// The first workout in programme order with no completed session.
    ///
    /// Ordered by week position then day, which is how a client reads a
    /// programme — not by id, which is insertion order and can differ.
    public var upNext: (week: Week, workout: Workout)? {
        guard let program else { return nil }
        let completed = Set(sessions.filter { !$0.isInProgress }.map(\.workoutID))
        for week in program.orderedWeeks {
            for workout in week.orderedWorkouts where !completed.contains(workout.id) {
                return (week, workout)
            }
        }
        return nil
    }

    /// Completed sessions, newest first. Unfinished ones belong in `resumable`,
    /// not in a list of things already done.
    public var recent: [WorkoutSession] {
        Array(
            sessions
                .filter { !$0.isInProgress }
                .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
                .prefix(3)
        )
    }

    public var completedWorkoutCount: Int {
        guard let program else { return 0 }
        let programmeWorkoutIDs = Set(program.weeks.flatMap(\.workouts).map(\.id))
        let completed = Set(sessions.filter { !$0.isInProgress }.map(\.workoutID))
        return programmeWorkoutIDs.intersection(completed).count
    }

    public var totalWorkoutCount: Int {
        program?.weeks.reduce(0) { $0 + $1.workouts.count } ?? 0
    }

    public func workoutName(for workoutID: Int) -> String? {
        program?.weeks.flatMap(\.workouts).first { $0.id == workoutID }?.name
    }

    public var isEmpty: Bool {
        assignment == nil && sessions.isEmpty
    }
}
