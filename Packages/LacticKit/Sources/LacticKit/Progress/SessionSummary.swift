import Foundation
import LacticCore

/// One completed session with its logged sets, and enough of the workout to
/// name what was performed.
///
/// The session payload carries `workout_exercise_id` but not always the
/// exercise behind it, which is why `lactic-web` renders `Exercise #<id>` on
/// this screen — a raw database id shown to a gym client. The references here
/// are what avoid that.
public struct SessionSummary: Sendable, Equatable {
    public let session: WorkoutSessionDetail
    public let workoutName: String?
    /// Keyed by `workout_exercise_id`, which is what an `ExerciseLog` carries.
    public let exerciseReferences: [Int: ExerciseReference]

    public init(
        session: WorkoutSessionDetail,
        workoutName: String?,
        exerciseReferences: [Int: ExerciseReference]
    ) {
        self.session = session
        self.workoutName = workoutName
        self.exerciseReferences = exerciseReferences
    }

    public struct ExerciseReference: Sendable, Equatable {
        public let exerciseID: Int?
        public let name: String?
        public let position: String?

        public init(exerciseID: Int?, name: String?, position: String?) {
            self.exerciseID = exerciseID
            self.name = name
            self.position = position
        }
    }

    /// Ordered by the coach's `A`-`Z` position rather than by id, so the
    /// summary reads in the order the workout was prescribed.
    ///
    /// `localizedStandardCompare` rather than `<`, so a hypothetical `A10`
    /// sorts after `A9` instead of before it.
    public var orderedExerciseLogs: [ExerciseLogDetail] {
        session.exerciseLogs.sorted { lhs, rhs in
            let lhsPosition = exerciseReferences[lhs.workoutExerciseID]?.position ?? ""
            let rhsPosition = exerciseReferences[rhs.workoutExerciseID]?.position ?? ""
            return lhsPosition.localizedStandardCompare(rhsPosition) == .orderedAscending
        }
    }

    public var totalSetCount: Int {
        session.exerciseLogs.reduce(0) { $0 + $1.setLogs.count }
    }

    public var totalReps: Int {
        session.exerciseLogs.flatMap(\.setLogs).reduce(0) { $0 + $1.reps }
    }

    public var totalVolumeKg: Decimal {
        session.exerciseLogs.flatMap(\.setLogs).reduce(Decimal.zero) { total, set in
            total + set.weightKg * Decimal(set.reps)
        }
    }

    public func reference(for log: ExerciseLogDetail) -> ExerciseReference? {
        exerciseReferences[log.workoutExerciseID]
    }
}
