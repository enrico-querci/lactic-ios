import Foundation
import Observation

/// One programme's structure: its weeks, the workouts on each day, and the
/// saved templates that can be dropped into it.
///
/// Every change applies the server's own response to `program` rather than
/// re-fetching the whole programme — the web learned that a full GET after
/// each edit doubled the requests without ever showing one was in flight.
/// `load()` is still worth calling on return from the workout editor, whose
/// changes move a workout's `volume_sets`.
@MainActor
@Observable
public final class ProgramBuilderModel: CoachActionPerforming {
    public let programID: Int

    public private(set) var program: CoachProgram?
    /// Best effort: a builder whose templates failed to load still builds.
    public private(set) var templates: [WorkoutTemplate] = []
    public private(set) var isLoading = false
    public internal(set) var isSubmitting = false
    public internal(set) var failure: CoachActionFailure?

    @ObservationIgnored private let client: APIClient

    public init(client: APIClient, programID: Int) {
        self.client = client
        self.programID = programID
    }

    public var orderedWeeks: [Week] {
        program?.orderedWeeks ?? []
    }

    /// Several workouts may share a day; they keep the server's order.
    public func workouts(inWeek weekID: Int, day: Int) -> [Workout] {
        program?.weeks.first { $0.id == weekID }?.workouts.filter { $0.day == day } ?? []
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let program: CoachProgram = client.send(CoachAPI.program(id: programID))
            async let templates: [WorkoutTemplate]? = try? client.send(CoachAPI.workoutTemplates)
            self.program = try await program
            self.templates = await templates ?? self.templates
            failure = nil
        } catch {
            failure = CoachActionFailure(error)
        }
    }

    // MARK: - Programme

    @discardableResult
    public func updateDetails(name: String, description: String?) async -> Bool {
        await perform {
            // An empty string rather than nil, so clearing the description
            // actually clears it: nil fields are dropped from a PATCH.
            let updated: Program = try await self.client.send(CoachAPI.updateProgram(
                id: self.programID, name: name, description: description.nilIfBlank ?? ""
            ))
            self.program?.name = updated.name
            self.program?.description = updated.description
        }
    }

    // MARK: - Weeks

    /// Weeks are unique by position within a programme, so the next one is
    /// one past the highest — not one past the count, which collides as soon
    /// as a week in the middle has been deleted.
    public var nextWeekPosition: Int {
        (program?.weeks.map(\.position).max() ?? 0) + 1
    }

    @discardableResult
    public func addWeek() async -> Bool {
        await perform {
            let summary: WeekSummary = try await self.client.send(
                CoachAPI.createWeek(programID: self.programID, position: self.nextWeekPosition)
            )
            self.program?.weeks.append(Week(summary: summary))
        }
    }

    /// Deletes the week and every workout in it.
    @discardableResult
    public func deleteWeek(id: Int) async -> Bool {
        await perform {
            try await self.client.sendIgnoringResponse(CoachAPI.deleteWeek(programID: self.programID, id: id))
            self.program?.weeks.removeAll { $0.id == id }
        }
    }

    // MARK: - Workouts

    /// Returns the new workout, so the screen can open it for exercises.
    public func addWorkout(weekID: Int, name: String, day: Int) async -> Workout? {
        var created: Workout?
        _ = await perform {
            let workout: Workout = try await self.client.send(
                CoachAPI.createWorkout(programID: self.programID, weekID: weekID, name: name, day: day)
            )
            self.insert(workout, intoWeek: weekID)
            created = workout
        }
        return created
    }

    /// Renames a workout or moves it to another day of the same week.
    @discardableResult
    public func updateWorkout(weekID: Int, id: Int, name: String, day: Int) async -> Bool {
        await perform {
            let updated: Workout = try await self.client.send(CoachAPI.updateWorkout(
                programID: self.programID, weekID: weekID, id: id, name: name, day: day
            ))
            self.updateWeek(weekID) { workouts in
                workouts.map { $0.id == id ? updated : $0 }
            }
        }
    }

    @discardableResult
    public func deleteWorkout(weekID: Int, id: Int) async -> Bool {
        await perform {
            try await self.client.sendIgnoringResponse(
                CoachAPI.deleteWorkout(programID: self.programID, weekID: weekID, id: id)
            )
            self.updateWeek(weekID) { $0.filter { $0.id != id } }
        }
    }

    /// Copies a workout with its exercises into any week of this programme,
    /// on any day.
    @discardableResult
    public func duplicateWorkout(weekID: Int, id: Int, toWeek targetWeekID: Int, day: Int) async -> Bool {
        await perform {
            // The response is the `:extended` view; decoding it as `Workout`
            // keeps what the week needs and ignores the nested exercises.
            let copy: Workout = try await self.client.send(CoachAPI.duplicateWorkout(
                programID: self.programID, weekID: weekID, id: id, targetWeekID: targetWeekID, day: day
            ))
            self.insert(copy, intoWeek: targetWeekID)
        }
    }

    // MARK: - Templates

    /// Snapshots a workout as a reusable template.
    @discardableResult
    public func saveAsTemplate(workoutID: Int, name: String) async -> Bool {
        await perform {
            let template: WorkoutTemplate = try await self.client.send(
                CoachAPI.createWorkoutTemplate(name: name, sourceWorkoutID: workoutID)
            )
            self.templates.append(template)
        }
    }

    /// Materialises a template as a new workout on `day` of a week.
    @discardableResult
    public func applyTemplate(id: Int, toWeek weekID: Int, day: Int) async -> Bool {
        await perform {
            let workout: Workout = try await self.client.send(
                CoachAPI.applyWorkoutTemplate(id: id, targetWeekID: weekID, day: day)
            )
            self.insert(workout, intoWeek: weekID)
        }
    }

    // MARK: - Internals

    private func insert(_ workout: Workout, intoWeek weekID: Int) {
        updateWeek(weekID) { $0 + [workout] }
    }

    private func updateWeek(_ weekID: Int, _ transform: ([Workout]) -> [Workout]) {
        guard var program, let index = program.weeks.firstIndex(where: { $0.id == weekID }) else { return }
        program.weeks[index] = program.weeks[index].replacingWorkouts(transform)
        self.program = program
    }
}
