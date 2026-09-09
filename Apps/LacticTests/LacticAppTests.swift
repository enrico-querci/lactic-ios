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
