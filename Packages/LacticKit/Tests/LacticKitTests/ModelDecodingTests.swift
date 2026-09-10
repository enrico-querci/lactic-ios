import Foundation
import LacticCore
import Testing
@testable import LacticKit

@Suite("Decoding real API responses")
struct ModelDecodingTests {
    @Test func decodesAuthResponse() throws {
        let session = try Fixture.decode(AuthSession.self, from: "auth_response")
        #expect(session.user.email == "alice@example.com")
        #expect(session.user.role == .client)
        #expect(!session.accessToken.isEmpty)
        #expect(session.refreshToken.count == 64, "the refresh token is SecureRandom.hex(32)")
    }

    /// `/me` and the auth response describe the same person with different
    /// shapes, which is why they are different types.
    @Test func decodesMeWithAnAvatarTheAuthResponseLacks() throws {
        let user = try Fixture.decode(User.self, from: "me")
        #expect(user.email == "alice@example.com")
        #expect(user.avatarURL == nil)

        #expect(throws: (any Error).self) {
            _ = try JSONCoding.decoder.decode(User.self, from: Fixture.data("auth_response"))
        }
    }

    @Test func decodesProgramAssignments() throws {
        let assignments = try Fixture.decode([ProgramAssignment].self, from: "client_programs")
        let assignment = try #require(assignments.first)
        #expect(assignment.status == .active)
        #expect(assignment.startDate.description == "2026-09-01")
        #expect(assignment.client.role == .client)
        #expect(!assignment.program.name.isEmpty)
    }

    @Test func decodesProgramDetailIncludingTheWriteOnlyAssignmentID() throws {
        let program = try Fixture.decode(ProgramDetail.self, from: "client_program_detail")
        #expect(program.assignmentID > 0, "the only place a client can learn this id")
        #expect(program.orderedWeeks.map(\.position) == [1, 2])

        let firstWeek = try #require(program.orderedWeeks.first)
        #expect(!firstWeek.workouts.isEmpty)
        #expect(firstWeek.orderedWorkouts.map(\.day) == firstWeek.orderedWorkouts.map(\.day).sorted())
    }

    @Test func decodesWorkoutDetail() throws {
        let workout = try Fixture.decode(WorkoutDetail.self, from: "client_workout_extended")
        #expect(!workout.workoutExercises.isEmpty)
        #expect(workout.volumeSets.values.allSatisfy { $0 > 0 })

        let first = try #require(workout.orderedExercises.first)
        #expect(first.position == "A", "position is a letter, not a number")
        #expect(first.weight != nil, "a decimal sent as a JSON string")
        #expect(first.exercise.hasAnimation)
        #expect(first.exercise.animationPath?.hasPrefix("/api/v1/") == true)
    }

    /// Exercises are ordered by a single uppercase letter carried as a string.
    @Test func ordersWorkoutExercisesByTheirLetterPosition() throws {
        let workout = try Fixture.decode(WorkoutDetail.self, from: "client_workout_extended")
        let positions = workout.orderedExercises.map(\.position)
        #expect(positions == positions.sorted())
    }

    @Test func decodesSessionsAndTheirNestedLogs() throws {
        let sessions = try Fixture.decode([WorkoutSession].self, from: "client_workout_sessions")
        #expect(!sessions.isEmpty)
        #expect(sessions.allSatisfy { $0.workoutName != nil })

        let detail = try Fixture.decode(WorkoutSessionDetail.self, from: "client_workout_session_extended")
        #expect(detail.workoutName == "Upper A")
        #expect(!detail.exerciseLogs.isEmpty)
        let log = try #require(detail.exerciseLogs.first)
        #expect(log.exerciseID == 143)
        #expect(log.exerciseName == "Bent-Over Barbell Row")
        #expect(log.position == "A")
        #expect(!log.setLogs.isEmpty)
        #expect(log.orderedSets.map(\.position) == log.orderedSets.map(\.position).sorted())
        #expect(log.setLogs.allSatisfy { $0.weightKg > 0 })
        #expect(detail.logsByWorkoutExerciseID[log.workoutExerciseID] == log)
    }

    @Test func decodesExerciseHistoryAsAFlatList() throws {
        let sets = try Fixture.decode([SetLog].self, from: "client_exercise_history")
        #expect(!sets.isEmpty)
        #expect(sets.allSatisfy { $0.reps > 0 })
        #expect(sets.allSatisfy { $0.workoutSessionID != nil })
        #expect(sets.allSatisfy { $0.performedAt != nil })
    }

    /// The detail view is a superset; the list view genuinely omits the extra
    /// keys rather than sending them as null, so a list row must not decode as
    /// a detail row.
    @Test func distinguishesExerciseListRowsFromDetailRows() throws {
        let detail = try Fixture.decode(ExerciseDetail.self, from: "client_exercise_detail")
        #expect(!detail.instructions.isEmpty)
        #expect(detail.locale == "en")
        #expect(detail.secondaryMuscles.allSatisfy { !$0.key.isEmpty })
        #expect(detail.primaryMuscle?.region != nil, "primary muscles carry a region")

        let listRows = try Fixture.decode([Exercise].self, from: "client_exercises_page")
        #expect(!listRows.isEmpty)

        let firstRowData = try JSONSerialization.data(
            withJSONObject: #require(
                JSONSerialization.jsonObject(with: Fixture.data("client_exercises_page")) as? [Any]
            )[0]
        )
        #expect(throws: (any Error).self) {
            _ = try JSONCoding.decoder.decode(ExerciseDetail.self, from: firstRowData)
        }
    }

    /// Names, muscles, equipment and even the volume_sets keys are localized
    /// server-side from Accept-Language.
    @Test func decodesTheItalianVariantOfTheSameWorkout() throws {
        let english = try Fixture.decode(WorkoutDetail.self, from: "client_workout_extended")
        let italian = try Fixture.decode(WorkoutDetail.self, from: "client_workout_extended_it")

        #expect(english.id == italian.id)
        #expect(english.orderedExercises.map(\.exercise.name) != italian.orderedExercises.map(\.exercise.name))
        #expect(
            Set(english.volumeSets.keys) != Set(italian.volumeSets.keys),
            "volume_sets keys are localized display names, not identifiers"
        )
        #expect(english.volumeSets.values.sorted() == italian.volumeSets.values.sorted())
    }
}
