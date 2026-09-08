import Foundation
import LacticCore

/// `ProgramBlueprint`, default view.
public struct Program: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let description: String?
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case createdAt = "created_at"
    }
}

/// `GET /client/programs/:program_id`.
///
/// Note the path takes the **program** id, not the assignment id, and the
/// response merges a top-level `assignment_id` into the blueprint. That id is
/// the only way to learn it: `WorkoutSessionBlueprint` never serializes
/// `program_assignment_id`, yet creating a session requires it.
public struct ProgramDetail: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let description: String?
    public let createdAt: Date
    public let weeks: [Week]
    public let assignmentID: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description, weeks
        case createdAt = "created_at"
        case assignmentID = "assignment_id"
    }

    /// Weeks in programme order.
    public var orderedWeeks: [Week] {
        weeks.sorted { $0.position < $1.position }
    }
}

/// A week inside `ProgramDetail`. Its `workouts` come from `WorkoutBlueprint`'s
/// **default** view, so they never carry `workout_exercises` — opening a
/// workout is always a second request to `GET /client/workouts/:id`.
public struct Week: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let position: Int
    public let workouts: [Workout]

    /// Workouts in day order. Several may share a day.
    public var orderedWorkouts: [Workout] {
        workouts.sorted { $0.day < $1.day }
    }
}

public struct Workout: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    /// 1-7, Monday-Sunday.
    public let day: Int
    /// Configured sets summed per muscle group. The keys are display names,
    /// **localized** and summed across colliding vocabularies, so they are
    /// presentation strings and never identifiers.
    public let volumeSets: [String: Int]

    enum CodingKeys: String, CodingKey {
        case id, name, day
        case volumeSets = "volume_sets"
    }
}

/// `GET /client/workouts/:id` — `WorkoutBlueprint`'s `:extended` view.
public struct WorkoutDetail: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let day: Int
    public let volumeSets: [String: Int]
    public let workoutExercises: [WorkoutExercise]

    enum CodingKeys: String, CodingKey {
        case id, name, day
        case volumeSets = "volume_sets"
        case workoutExercises = "workout_exercises"
    }

    /// Ordered by the `A`-`Z` position label, which is a string on the wire.
    public var orderedExercises: [WorkoutExercise] {
        workoutExercises.sorted { $0.position.localizedStandardCompare($1.position) == .orderedAscending }
    }
}

/// One configured exercise inside a workout: the coach's prescription.
public struct WorkoutExercise: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    /// A single uppercase letter, `A`-`Z`, unique within the workout. A
    /// **string**, unlike `Week.position` and `SetLog.position`, which are Ints.
    public let position: String
    public let sets: Int
    public let reps: Int
    public let restSeconds: Int?
    /// Reps in reserve.
    public let rir: Int?
    @LenientDecimalOptional public var weight: Decimal?
    public let notes: String?
    public let exercise: Exercise

    enum CodingKeys: String, CodingKey {
        case id, position, sets, reps, rir, weight, notes, exercise
        case restSeconds = "rest_seconds"
    }

    /// The coach's target rest, or the 90s the web's builder defaults to.
    public var effectiveRestSeconds: Int {
        restSeconds ?? 90
    }
}

public enum AssignmentStatus: String, Codable, Sendable, CaseIterable {
    case active, completed, paused
}

/// `GET /client/programs` returns these, filtered to `active` server-side —
/// paused and completed assignments never appear.
public struct ProgramAssignment: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let startDate: CalendarDate
    public let status: AssignmentStatus
    public let notes: String?
    public let program: Program
    public let client: User

    enum CodingKeys: String, CodingKey {
        case id, status, notes, program, client
        case startDate = "start_date"
    }
}
