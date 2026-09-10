import Foundation
import LacticCore
import LacticKit
import Testing
@testable import Lactic

@Test func appModuleLoads() {
    #expect(Bool(true))
}

@Test func homeSnapshotPrioritizesResumeAndProgrammeOrder() throws {
    let program = try JSONCoding.decoder.decode(ProgramDetail.self, from: Data(programJSON.utf8))
    let sessions = try JSONCoding.decoder.decode([WorkoutSession].self, from: Data(sessionsJSON.utf8))
    let snapshot = HomeModel.Snapshot(
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
    let snapshot = ProgramDetailModel.Snapshot(program: program, sessions: sessions)
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
    let snapshot = HistoryModel.Snapshot(sessions: sessions)

    #expect(snapshot.completed.count == 2)
    #expect(snapshot.inProgress.count == 2)
    #expect(snapshot.distinctWorkoutCount == 1)
    #expect(snapshot.totalTrainingTime == 6600)
}

@Test func exerciseProgressGroupsSetsBySessionAndDerivesChange() throws {
    let exercise = try JSONCoding.decoder.decode(ExerciseDetail.self, from: Data(exerciseJSON.utf8))
    let history = try JSONCoding.decoder.decode([SetLog].self, from: Data(exerciseHistoryJSON.utf8))
    let detail = ExerciseDetailModel.Detail(exercise: exercise, history: history)

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
  {"id":1,"position":1,"weight_kg":"72.5","reps":8,"workout_session_id":10,"performed_at":"2026-09-01T18:00:00.000Z"},
  {"id":2,"position":2,"weight_kg":"75","reps":8,"workout_session_id":10,"performed_at":"2026-09-01T18:00:00.000Z"},
  {"id":3,"position":1,"weight_kg":"80","reps":7,"workout_session_id":11,"performed_at":"2026-09-08T18:00:00.000Z"},
  {"id":4,"position":2,"weight_kg":"80","reps":7,"workout_session_id":11,"performed_at":"2026-09-08T18:00:00.000Z"}
]
"""
