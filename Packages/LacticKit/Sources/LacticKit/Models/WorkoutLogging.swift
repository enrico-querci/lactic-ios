import Foundation
import LacticCore

/// `WorkoutSessionBlueprint`, default view.
///
/// `program_assignment_id` is **write-only**: required when creating a session,
/// never serialized back. Clients must remember it themselves, from
/// `ProgramDetail.assignmentID`.
public struct WorkoutSession: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let workoutID: Int
    public let startedAt: Date?
    public let completedAt: Date?
    public let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, notes
        case workoutID = "workout_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }

    public var isInProgress: Bool {
        completedAt == nil
    }
}

/// `GET /client/workout_sessions/:id` — the `:extended` view, and the only way
/// to rehydrate a session in progress after the app is killed mid-workout.
public struct WorkoutSessionDetail: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let workoutID: Int
    public let startedAt: Date?
    public let completedAt: Date?
    public let notes: String?
    public let exerciseLogs: [ExerciseLogDetail]

    enum CodingKeys: String, CodingKey {
        case id, notes
        case workoutID = "workout_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case exerciseLogs = "exercise_logs"
    }

    public var isInProgress: Bool {
        completedAt == nil
    }

    /// Logs keyed by the workout exercise they belong to, which is how the
    /// execution screen looks them up.
    public var logsByWorkoutExerciseID: [Int: ExerciseLogDetail] {
        Dictionary(uniqueKeysWithValues: exerciseLogs.map { ($0.workoutExerciseID, $0) })
    }
}

/// The response to `POST /client/exercise_logs`: no `set_logs`, and no
/// `workout_session_id` either, though creating one requires it.
public struct ExerciseLog: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let workoutExerciseID: Int
    public let notes: String?
    public let photoURL: String?

    enum CodingKeys: String, CodingKey {
        case id, notes
        case workoutExerciseID = "workout_exercise_id"
        case photoURL = "photo_url"
    }
}

/// The same log as nested inside a session's `:extended` view, which does carry
/// its sets.
public struct ExerciseLogDetail: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let workoutExerciseID: Int
    public let notes: String?
    public let photoURL: String?
    public let setLogs: [SetLog]

    enum CodingKeys: String, CodingKey {
        case id, notes
        case workoutExerciseID = "workout_exercise_id"
        case photoURL = "photo_url"
        case setLogs = "set_logs"
    }

    public var orderedSets: [SetLog] {
        setLogs.sorted { $0.position < $1.position }
    }
}

/// One performed set. `position` is 1-based and unique per exercise log — the
/// database enforces it, which is what lets a retried create surface as a 422
/// rather than a duplicate row.
public struct SetLog: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let position: Int
    @LenientDecimal public var weightKg: Decimal
    public let reps: Int

    enum CodingKeys: String, CodingKey {
        case id, position, reps
        case weightKg = "weight_kg"
    }
}
