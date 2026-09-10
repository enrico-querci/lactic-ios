import Foundation
import LacticCore

/// The programme-building half of the coach API: programs, weeks, workouts,
/// their configured exercises, the catalog, templates and assignments.
///
/// Split from `CoachAPI.swift` purely for file length; it is one namespace.
public extension CoachAPI {
    // MARK: - Programs

    static var programs: Endpoint {
        Endpoint(path: "/coach/programs")
    }

    static func program(id: Int) -> Endpoint {
        Endpoint(path: "/coach/programs/\(id)")
    }

    static func createProgram(name: String, description: String?) throws -> Endpoint {
        try Endpoint(
            method: .post, path: "/coach/programs",
            body: encode("program", ["name": name, "description": description])
        )
    }

    static func updateProgram(id: Int, name: String?, description: String?) throws -> Endpoint {
        try Endpoint(
            method: .patch, path: "/coach/programs/\(id)",
            body: encode("program", ["name": name, "description": description])
        )
    }

    static func deleteProgram(id: Int) -> Endpoint {
        Endpoint(method: .delete, path: "/coach/programs/\(id)")
    }

    // MARK: - Weeks

    static func weeks(programID: Int) -> Endpoint {
        Endpoint(path: "/coach/programs/\(programID)/weeks")
    }

    static func createWeek(programID: Int, position: Int?) throws -> Endpoint {
        try Endpoint(
            method: .post, path: "/coach/programs/\(programID)/weeks",
            body: encode("week", ["position": position])
        )
    }

    static func updateWeek(programID: Int, id: Int, position: Int) throws -> Endpoint {
        try Endpoint(
            method: .patch, path: "/coach/programs/\(programID)/weeks/\(id)",
            body: encode("week", ["position": position])
        )
    }

    static func deleteWeek(programID: Int, id: Int) -> Endpoint {
        Endpoint(method: .delete, path: "/coach/programs/\(programID)/weeks/\(id)")
    }

    // MARK: - Workouts

    static func workouts(programID: Int, weekID: Int) -> Endpoint {
        Endpoint(path: "/coach/programs/\(programID)/weeks/\(weekID)/workouts")
    }

    static func workout(programID: Int, weekID: Int, id: Int) -> Endpoint {
        Endpoint(path: "/coach/programs/\(programID)/weeks/\(weekID)/workouts/\(id)")
    }

    /// `day` is 1-7, and more than one workout may sit on the same day.
    static func createWorkout(programID: Int, weekID: Int, name: String, day: Int) throws -> Endpoint {
        try Endpoint(
            method: .post, path: "/coach/programs/\(programID)/weeks/\(weekID)/workouts",
            body: encode("workout", ["name": name, "day": day])
        )
    }

    static func updateWorkout(
        programID: Int, weekID: Int, id: Int, name: String?, day: Int?
    ) throws -> Endpoint {
        try Endpoint(
            method: .patch, path: "/coach/programs/\(programID)/weeks/\(weekID)/workouts/\(id)",
            body: encode("workout", ["name": name, "day": day])
        )
    }

    static func deleteWorkout(programID: Int, weekID: Int, id: Int) -> Endpoint {
        Endpoint(method: .delete, path: "/coach/programs/\(programID)/weeks/\(weekID)/workouts/\(id)")
    }

    /// Copies a workout, within its week or into another one.
    static func duplicateWorkout(programID: Int, weekID: Int, id: Int) -> Endpoint {
        Endpoint(method: .post, path: "/coach/programs/\(programID)/weeks/\(weekID)/workouts/\(id)/duplicate")
    }

    // MARK: - Workout exercises

    static func workoutExercises(workoutID: Int) -> Endpoint {
        Endpoint(path: "/coach/workouts/\(workoutID)/workout_exercises")
    }

    /// A configured exercise, as the coach prescribes it.
    ///
    /// A struct rather than a long parameter list: eight of these are easy to
    /// transpose at a call site, and `sets`/`reps`/`restSeconds` are all `Int`.
    struct WorkoutExercisePlan: Hashable, Sendable {
        public var exerciseID: Int
        /// The `A`-`Z` ordering the client sees, not a number. Server-assigned
        /// when omitted.
        public var position: String?
        public var sets: Int
        public var reps: Int
        public var restSeconds: Int
        public var rir: Int?
        public var weight: Decimal?
        public var notes: String?

        public init(
            exerciseID: Int, position: String? = nil, sets: Int, reps: Int,
            restSeconds: Int, rir: Int? = nil, weight: Decimal? = nil, notes: String? = nil
        ) {
            self.exerciseID = exerciseID
            self.position = position
            self.sets = sets
            self.reps = reps
            self.restSeconds = restSeconds
            self.rir = rir
            self.weight = weight
            self.notes = notes
        }
    }

    /// A partial edit. Every field is optional and only what is set is sent,
    /// so an untouched field keeps whatever the server holds.
    struct WorkoutExerciseChanges: Hashable, Sendable {
        public var position: String?
        public var sets: Int?
        public var reps: Int?
        public var restSeconds: Int?
        public var rir: Int?
        public var weight: Decimal?
        public var notes: String?

        public init(
            position: String? = nil, sets: Int? = nil, reps: Int? = nil, restSeconds: Int? = nil,
            rir: Int? = nil, weight: Decimal? = nil, notes: String? = nil
        ) {
            self.position = position
            self.sets = sets
            self.reps = reps
            self.restSeconds = restSeconds
            self.rir = rir
            self.weight = weight
            self.notes = notes
        }
    }

    static func createWorkoutExercise(
        workoutID: Int, plan: WorkoutExercisePlan
    ) throws -> Endpoint {
        try Endpoint(
            method: .post, path: "/coach/workouts/\(workoutID)/workout_exercises",
            body: encode("workout_exercise", [
                "exercise_id": plan.exerciseID, "position": plan.position,
                "sets": plan.sets, "reps": plan.reps, "rest_seconds": plan.restSeconds,
                "rir": plan.rir, "weight": plan.weight, "notes": plan.notes,
            ])
        )
    }

    static func updateWorkoutExercise(
        workoutID: Int, id: Int, changes: WorkoutExerciseChanges
    ) throws -> Endpoint {
        try Endpoint(
            method: .patch, path: "/coach/workouts/\(workoutID)/workout_exercises/\(id)",
            body: encode("workout_exercise", [
                "position": changes.position, "sets": changes.sets, "reps": changes.reps,
                "rest_seconds": changes.restSeconds, "rir": changes.rir,
                "weight": changes.weight, "notes": changes.notes,
            ])
        )
    }

    static func deleteWorkoutExercise(workoutID: Int, id: Int) -> Endpoint {
        Endpoint(method: .delete, path: "/coach/workouts/\(workoutID)/workout_exercises/\(id)")
    }

    // MARK: - Exercises

    /// The catalog, paged through the same `X-Total-Count`/`X-Page` headers the
    /// client's list uses. Every filter is optional and omitted when nil.
    static func exercises(
        search: String? = nil, muscle: String? = nil, primaryMuscle: String? = nil,
        equipment: String? = nil, category: String? = nil, difficulty: String? = nil,
        custom: Bool? = nil, muscleGroup: String? = nil, page: Int? = nil, perPage: Int? = nil
    ) -> Endpoint {
        let pairs: [(String, String?)] = [
            ("search", search), ("muscle", muscle), ("primary_muscle", primaryMuscle),
            ("equipment", equipment), ("category", category), ("difficulty", difficulty),
            ("custom", custom.map(String.init)), ("muscle_group", muscleGroup),
            ("page", page.map(String.init)), ("per_page", perPage.map(String.init)),
        ]
        return Endpoint(
            path: "/coach/exercises",
            query: pairs.compactMap { name, value in
                value.map { URLQueryItem(name: name, value: $0) }
            }
        )
    }

    static func exercise(id: Int) -> Endpoint {
        Endpoint(path: "/coach/exercises/\(id)")
    }

    static func createExercise(
        name: String, muscleGroup: String, videoURL: String?, thumbnailURL: String?
    ) throws -> Endpoint {
        try Endpoint(
            method: .post, path: "/coach/exercises",
            body: encode("exercise", [
                "name": name, "muscle_group": muscleGroup,
                "video_url": videoURL, "thumbnail_url": thumbnailURL,
            ])
        )
    }

    static func updateExercise(
        id: Int, name: String? = nil, muscleGroup: String? = nil,
        videoURL: String? = nil, thumbnailURL: String? = nil
    ) throws -> Endpoint {
        try Endpoint(
            method: .patch, path: "/coach/exercises/\(id)",
            body: encode("exercise", [
                "name": name, "muscle_group": muscleGroup,
                "video_url": videoURL, "thumbnail_url": thumbnailURL,
            ])
        )
    }

    static func deleteExercise(id: Int) -> Endpoint {
        Endpoint(method: .delete, path: "/coach/exercises/\(id)")
    }

    static var exerciseTaxonomy: Endpoint {
        Endpoint(path: "/coach/exercise_taxonomy")
    }

    // MARK: - Workout templates

    static var workoutTemplates: Endpoint {
        Endpoint(path: "/coach/workout_templates")
    }

    static func workoutTemplate(id: Int) -> Endpoint {
        Endpoint(path: "/coach/workout_templates/\(id)")
    }

    /// Top level rather than wrapped, matching the controller.
    static func createWorkoutTemplate(name: String, sourceWorkoutID: Int) throws -> Endpoint {
        try Endpoint(
            method: .post, path: "/coach/workout_templates",
            body: JSONCoding.encoder.encode(
                CreateTemplate(name: name, sourceWorkoutID: sourceWorkoutID)
            )
        )
    }

    /// Materialises the template into a week, returning the new workout.
    static func applyWorkoutTemplate(id: Int, targetWeekID: Int) throws -> Endpoint {
        try Endpoint(
            method: .post, path: "/coach/workout_templates/\(id)/apply",
            body: JSONCoding.encoder.encode(ApplyTemplate(targetWeekID: targetWeekID))
        )
    }

    static func deleteWorkoutTemplate(id: Int) -> Endpoint {
        Endpoint(method: .delete, path: "/coach/workout_templates/\(id)")
    }

    // MARK: - Program assignments

    static var programAssignments: Endpoint {
        Endpoint(path: "/coach/program_assignments")
    }

    static func programAssignment(id: Int) -> Endpoint {
        Endpoint(path: "/coach/program_assignments/\(id)")
    }

    static func createProgramAssignment(
        programID: Int, clientID: Int, startDate: CalendarDate, notes: String?
    ) throws -> Endpoint {
        try Endpoint(
            method: .post, path: "/coach/program_assignments",
            body: encode("program_assignment", [
                "program_id": programID, "client_id": clientID,
                "start_date": startDate, "notes": notes,
            ])
        )
    }

    static func updateProgramAssignment(
        id: Int, startDate: CalendarDate? = nil, status: AssignmentStatus? = nil, notes: String? = nil
    ) throws -> Endpoint {
        try Endpoint(
            method: .patch, path: "/coach/program_assignments/\(id)",
            body: encode("program_assignment", [
                "start_date": startDate, "status": status?.rawValue, "notes": notes,
            ])
        )
    }

    static func deleteProgramAssignment(id: Int) -> Endpoint {
        Endpoint(method: .delete, path: "/coach/program_assignments/\(id)")
    }
}
