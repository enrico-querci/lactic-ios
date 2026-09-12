import Foundation
import LacticCore

/// Everything the client has logged, completed and in progress.
public struct TrainingHistory: Sendable, Equatable {
    public let sessions: [WorkoutSession]

    public init(sessions: [WorkoutSession]) {
        self.sessions = sessions
    }

    public var completed: [WorkoutSession] {
        sessions.filter { !$0.isInProgress }
    }

    public var inProgress: [WorkoutSession] {
        sessions.filter(\.isInProgress)
    }

    /// Sums only sessions with both ends recorded. An unfinished session has no
    /// duration yet, and treating "now" as its end would make the total grow
    /// while the client stares at the screen.
    public var totalTrainingTime: TimeInterval {
        completed.reduce(0) { total, session in
            guard let startedAt = session.startedAt, let completedAt = session.completedAt else {
                return total
            }
            return total + completedAt.timeIntervalSince(startedAt)
        }
    }

    public var distinctWorkoutCount: Int {
        Set(completed.map(\.workoutID)).count
    }
}
