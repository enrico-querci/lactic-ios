import Foundation
import Observation

/// What a coach prescribes for one exercise in a workout — everything except
/// which exercise it is and its letter, which an edit never changes.
///
/// A value type so an edit form can bind to it field by field and hand the
/// whole thing back.
public struct WorkoutExercisePrescription: Equatable, Sendable {
    public var sets: Int
    public var reps: Int
    public var restSeconds: Int
    /// Reps in reserve; `nil` for none.
    public var rir: Int?
    /// Suggested load in kilograms; `nil` for none.
    public var weight: Decimal?
    public var notes: String

    public init(sets: Int, reps: Int, restSeconds: Int, rir: Int? = nil, weight: Decimal? = nil, notes: String = "") {
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.rir = rir
        self.weight = weight
        self.notes = notes
    }

    public init(_ exercise: WorkoutExercise) {
        self.init(
            sets: exercise.sets, reps: exercise.reps, restSeconds: exercise.effectiveRestSeconds,
            rir: exercise.rir, weight: exercise.weight, notes: exercise.notes ?? ""
        )
    }

    /// The server's own rules: at least one set and one rep, and nothing
    /// negative. Checked here so a form can disable Save instead of a 422.
    public var isValid: Bool {
        sets > 0 && reps > 0 && restSeconds >= 0 && (rir ?? 0) >= 0 && (weight ?? 0) >= 0
    }
}

/// One workout's prescription: which exercises, in which order, for how many
/// sets and reps.
@MainActor
@Observable
public final class WorkoutEditorModel: CoachActionPerforming {
    public let programID: Int
    public let weekID: Int
    public let workoutID: Int

    public private(set) var workout: WorkoutDetail?
    public private(set) var isLoading = false
    public internal(set) var isSubmitting = false
    public internal(set) var failure: CoachActionFailure?

    /// What a new exercise is prescribed until the coach changes it — the same
    /// defaults as the web's builder.
    public static let defaultSets = 3
    public static let defaultReps = 10
    public static let defaultRestSeconds = 90

    @ObservationIgnored private let client: APIClient

    public init(client: APIClient, programID: Int, weekID: Int, workoutID: Int) {
        self.client = client
        self.programID = programID
        self.weekID = weekID
        self.workoutID = workoutID
    }

    public var exercises: [WorkoutExercise] {
        workout?.orderedExercises ?? []
    }

    /// Positions are single letters, `A`-`Z`, unique within a workout — so a
    /// workout holds at most 26 exercises.
    public var canAddExercise: Bool {
        Self.nextFreePosition(after: exercises.map(\.position)) != nil
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            workout = try await client.send(endpoint)
            failure = nil
        } catch {
            if error.isCancellation {
                return
            }
            failure = CoachActionFailure(error)
        }
    }

    /// Adds an exercise at the first free letter with the default prescription.
    @discardableResult
    public func addExercise(_ exercise: Exercise) async -> Bool {
        guard let position = Self.nextFreePosition(after: exercises.map(\.position)) else { return false }
        return await perform {
            let added: WorkoutExercise = try await self.client.send(CoachAPI.createWorkoutExercise(
                workoutID: self.workoutID,
                plan: .init(
                    exerciseID: exercise.id, position: position,
                    sets: Self.defaultSets, reps: Self.defaultReps, restSeconds: Self.defaultRestSeconds
                )
            ))
            self.apply { $0 + [added] }
            await self.refreshVolume()
        }
    }

    /// Replaces an exercise's whole prescription, so clearing RIR, weight or
    /// notes clears them rather than leaving the old value in place.
    @discardableResult
    public func updateExercise(id: Int, to prescription: WorkoutExercisePrescription) async -> Bool {
        guard let current = exercises.first(where: { $0.id == id }) else { return false }
        return await perform {
            let updated: WorkoutExercise = try await self.client.send(CoachAPI.replaceWorkoutExercise(
                workoutID: self.workoutID, id: id,
                plan: .init(
                    exerciseID: current.exercise.id, position: current.position,
                    sets: prescription.sets, reps: prescription.reps, restSeconds: prescription.restSeconds,
                    rir: prescription.rir, weight: prescription.weight,
                    notes: Optional(prescription.notes).nilIfBlank
                )
            ))
            self.apply { $0.map { $0.id == id ? updated : $0 } }
            await self.refreshVolume()
        }
    }

    @discardableResult
    public func removeExercise(id: Int) async -> Bool {
        await perform {
            try await self.client.sendIgnoringResponse(
                CoachAPI.deleteWorkoutExercise(workoutID: self.workoutID, id: id)
            )
            self.apply { $0.filter { $0.id != id } }
            await self.refreshVolume()
        }
    }

    /// The first letter not already taken. Not "one past the count": after a
    /// removal in the middle, that letter is still in use and the server
    /// refuses the duplicate.
    static func nextFreePosition(after used: [String]) -> String? {
        let taken = Set(used)
        return (UnicodeScalar("A").value ... UnicodeScalar("Z").value)
            .lazy
            .compactMap { UnicodeScalar($0).map { String(Character($0)) } }
            .first { !taken.contains($0) }
    }

    // MARK: - Internals

    private var endpoint: Endpoint {
        CoachAPI.workout(programID: programID, weekID: weekID, id: workoutID)
    }

    private func apply(_ transform: ([WorkoutExercise]) -> [WorkoutExercise]) {
        guard let workout else { return }
        self.workout = WorkoutDetail(
            id: workout.id, name: workout.name, day: workout.day,
            volumeSets: workout.volumeSets, workoutExercises: transform(workout.workoutExercises)
        )
    }

    /// `volume_sets` is derived server-side from the exercises, so it goes
    /// stale with every change. Best effort: the change itself succeeded.
    private func refreshVolume() async {
        if let fresh: WorkoutDetail = try? await client.send(endpoint) {
            workout = fresh
        }
    }
}
