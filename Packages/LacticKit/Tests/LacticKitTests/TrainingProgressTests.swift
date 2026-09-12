import Foundation
import LacticCore
import Testing
@testable import LacticKit

/// Derived training metrics, over payloads captured from a running API.
///
/// These moved out of the app target with the arithmetic itself: they run on
/// the host in milliseconds rather than needing a simulator, and they no
/// longer sit in files the visual pass edits.
@Suite("Training progress")
struct TrainingProgressTests {
    @Test func homeSnapshotPrioritizesResumeAndProgrammeOrder() throws {
        let program = try JSONCoding.decoder.decode(ProgramDetail.self, from: Data(programJSON.utf8))
        let sessions = try JSONCoding.decoder.decode([WorkoutSession].self, from: Data(sessionsJSON.utf8))
        let snapshot = HomeSnapshot(
            assignment: nil,
            program: program,
            featuredExerciseCount: nil,
            featuredTargetSets: nil,
            sessions: sessions
        )

        #expect(snapshot.resumable?.id == 4)
        #expect(snapshot.upNext?.week.position == 1)
        #expect(snapshot.upNext?.workout.id == 3)
        #expect(snapshot.completedWorkoutCount == 1)
        #expect(snapshot.totalWorkoutCount == 4)
        #expect(snapshot.recent.map(\.id) == [2, 1])
        #expect(snapshot.workoutName(for: 5) == "Arms & Shoulders")
    }

    @Test func programmeSnapshotDerivesProgressAndWorkoutStatus() throws {
        let program = try JSONCoding.decoder.decode(ProgramDetail.self, from: Data(programJSON.utf8))
        let sessions = try JSONCoding.decoder.decode([WorkoutSession].self, from: Data(sessionsJSON.utf8))
        let snapshot = ProgrammeProgress(program: program, sessions: sessions)
        let firstWeek = try #require(program.orderedWeeks.first)

        #expect(snapshot.totalWorkoutCount == 4)
        #expect(snapshot.completedWorkoutCount == 1)
        #expect(snapshot.progress(in: firstWeek).completed == 1)
        #expect(snapshot.progress(in: firstWeek).total == 2)
        #expect(snapshot.status(for: 2) == .completed)
        #expect(snapshot.status(for: 3) == .upcoming)
        #expect(snapshot.status(for: 4) == .inProgress)
    }

    @Test func historySnapshotDerivesSummaryMetrics() throws {
        let sessions = try JSONCoding.decoder.decode([WorkoutSession].self, from: Data(sessionsJSON.utf8))
        let snapshot = TrainingHistory(sessions: sessions)

        #expect(snapshot.completed.count == 2)
        #expect(snapshot.inProgress.count == 2)
        #expect(snapshot.distinctWorkoutCount == 1)
        #expect(snapshot.totalTrainingTime == 6600)
    }

    @Test func exerciseProgressGroupsSetsBySessionAndDerivesChange() throws {
        let exercise = try JSONCoding.decoder.decode(ExerciseDetail.self, from: Data(exerciseJSON.utf8))
        let history = try JSONCoding.decoder.decode([SetLog].self, from: Data(exerciseHistoryJSON.utf8))
        let detail = ExerciseProgress(exercise: exercise, history: history)

        #expect(detail.historySessions.count == 2)
        #expect(detail.historySessions.first?.sets.count == 2)
        #expect(detail.bestWeight == Decimal(string: "80"))
        #expect(detail.totalReps == 30)
        #expect(detail.bestWeightChange == Decimal(string: "5"))
    }

    private let programJSON = """
    {
      "id": 2,
      "created_at": "2026-09-08T10:56:02.650Z",
      "description": null,
      "name": "Upper / Lower Strength",
      "weeks": [
        {"id": 3, "position": 2, "workouts": [
          {"id": 4, "day": 1, "name": "Upper B", "volume_sets": {}},
          {"id": 5, "day": 4, "name": "Arms & Shoulders", "volume_sets": {}}
        ]},
        {"id": 2, "position": 1, "workouts": [
          {"id": 3, "day": 3, "name": "Lower A", "volume_sets": {}},
          {"id": 2, "day": 1, "name": "Upper A", "volume_sets": {}}
        ]}
      ],
      "assignment_id": 1
    }
    """

    private let sessionsJSON = """
    [
      {"id": 3, "completed_at": null, "notes": null, "started_at": "2026-09-09T15:00:00.000Z", "workout_id": 4},
      {"id": 1, "completed_at": "2026-09-06T19:05:00.000Z", "notes": null,
       "started_at": "2026-09-06T18:00:00.000Z", "workout_id": 2},
      {"id": 4, "completed_at": null, "notes": null, "started_at": "2026-09-09T16:15:00.000Z", "workout_id": 5},
      {"id": 2, "completed_at": "2026-09-08T11:45:00.000Z", "notes": null,
       "started_at": "2026-09-08T11:00:00.000Z", "workout_id": 2}
    ]
    """

    private let exerciseJSON = """
    {
      "id": 145, "active": true, "animation_url": null, "assignable": true, "category": "strength",
      "description": "A foundational lower-body movement.", "difficulty": "intermediate",
      "equipment": [{"key":"barbell","name":"Barbell"}], "force": "push", "has_animation": false,
      "instructions": ["Brace.", "Squat.", "Stand."], "is_custom": false, "locale": "en",
      "mechanic": "compound", "muscle_group": "Quadriceps", "name": "Back Squat",
      "prescription_type": "repetitions",
      "primary_muscle": {"key":"quads","name":"Quadriceps","region":"Upper Legs"},
      "secondary_muscles": [], "thumbnail_url": null, "video_url": null
    }
    """

    private let exerciseHistoryJSON = """
    [
      {"id":1,"position":1,"weight_kg":"72.5","reps":8,"workout_session_id":10,
       "performed_at":"2026-09-01T18:00:00.000Z"},
      {"id":2,"position":2,"weight_kg":"75","reps":8,"workout_session_id":10,"performed_at":"2026-09-01T18:00:00.000Z"},
      {"id":3,"position":1,"weight_kg":"80","reps":7,"workout_session_id":11,"performed_at":"2026-09-08T18:00:00.000Z"},
      {"id":4,"position":2,"weight_kg":"80","reps":7,"workout_session_id":11,"performed_at":"2026-09-08T18:00:00.000Z"}
    ]
    """

    /// Rows predating `workout_session_id` must not collapse into one session.
    /// The fallback key is the negated set id, which cannot collide with a
    /// real session id.
    @Test func undatedRowsStayDistinctSessions() throws {
        let json = """
        [{"id":1,"position":1,"weight_kg":"60","reps":5},
         {"id":2,"position":1,"weight_kg":"65","reps":5}]
        """
        let history = try JSONCoding.decoder.decode([SetLog].self, from: Data(json.utf8))
        let exercise = try JSONCoding.decoder.decode(ExerciseDetail.self, from: Data(exerciseJSON.utf8))
        let progress = ExerciseProgress(exercise: exercise, history: history)

        #expect(progress.historySessions.count == 2)
        // Undated sessions cannot be placed on a timeline, so there is no
        // trend to report rather than a fabricated one.
        #expect(progress.datedHistorySessions.isEmpty)
        #expect(progress.bestWeightChange == nil)
        #expect(progress.bestWeight == Decimal(string: "65"))
    }

    /// A single session is a starting point, not progress. Reporting zero
    /// would imply a plateau the client has not actually hit.
    @Test func oneSessionReportsNoChange() throws {
        let json = """
        [{"id":1,"position":1,"weight_kg":"60","reps":5,"workout_session_id":9,
          "performed_at":"2026-09-01T18:00:00.000Z"}]
        """
        let history = try JSONCoding.decoder.decode([SetLog].self, from: Data(json.utf8))
        let exercise = try JSONCoding.decoder.decode(ExerciseDetail.self, from: Data(exerciseJSON.utf8))
        #expect(ExerciseProgress(exercise: exercise, history: history).bestWeightChange == nil)
    }

    /// Ordered by the coach's A-Z position, not by id, and compared so that a
    /// hypothetical `A10` sorts after `A9` rather than before it.
    @Test func sessionLogsFollowThePrescribedOrder() throws {
        let session = try Fixture.decode(
            WorkoutSessionDetail.self, from: "client_workout_session_extended"
        )
        let references: [Int: SessionSummary.ExerciseReference] = [
            4: .init(exerciseID: 143, name: nil, position: "A10"),
            5: .init(exerciseID: 144, name: nil, position: "A9"),
            6: .init(exerciseID: 145, name: nil, position: "B"),
        ]
        let summary = SessionSummary(
            session: session, workoutName: "Upper A", exerciseReferences: references
        )

        #expect(summary.orderedExerciseLogs.map(\.workoutExerciseID) == [5, 4, 6])
        #expect(summary.totalSetCount == 9)
        #expect(summary.totalReps == 72)
    }
}
