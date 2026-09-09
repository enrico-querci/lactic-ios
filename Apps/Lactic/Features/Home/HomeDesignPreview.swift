#if DEBUG
    import Foundation
    import LacticCore
    import LacticKit
    import LacticUI
    import SwiftUI

    struct HomeDesignPreview: View {
        @State private var snapshot: HomeModel.Snapshot?
        @State private var errorMessage: String?

        var body: some View {
            Group {
                if let snapshot {
                    HomeDashboard(snapshot: snapshot, locale: .english)
                } else if let errorMessage {
                    Text(errorMessage)
                } else {
                    ProgressView()
                }
            }
            .background(LacticColor.surface)
            .navigationTitle("Lactic")
            .task {
                do {
                    snapshot = try Self.fixture(resume: ProcessInfo.processInfo.arguments.contains("--home-resume"))
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }

        private static func fixture(resume: Bool) throws -> HomeModel.Snapshot {
            let assignments = try JSONCoding.decoder.decode(
                [ProgramAssignment].self, from: Data(assignmentJSON.utf8)
            )
            let program = try JSONCoding.decoder.decode(ProgramDetail.self, from: Data(programJSON.utf8))
            var sessions = try JSONCoding.decoder.decode([WorkoutSession].self, from: Data(sessionsJSON.utf8))
            if resume {
                try sessions.append(JSONCoding.decoder.decode(WorkoutSession.self, from: Data(resumeJSON.utf8)))
            }
            return HomeModel.Snapshot(
                assignment: assignments.first,
                program: program,
                featuredExerciseCount: resume ? 5 : 4,
                featuredTargetSets: resume ? 15 : 12,
                sessions: sessions
            )
        }

        private static let assignmentJSON = """
        [{
          "id": 1,
          "client": {
            "id": 4,
            "avatar_url": null,
            "email": "alice@example.com",
            "name": "Alice Client",
            "role": "client"
          },
          "notes": "Keep the tempo controlled and leave two reps in reserve.",
          "program": {
            "id": 2,
            "created_at": "2026-09-08T10:56:02.650Z",
            "description": "Two-week upper/lower split.",
            "name": "Upper / Lower Strength"
          },
          "start_date": "2026-09-01",
          "status": "active"
        }]
        """

        private static let programJSON = """
        {
          "id": 2,
          "created_at": "2026-09-08T10:56:02.650Z",
          "description": "Two-week upper/lower split.",
          "name": "Upper / Lower Strength",
          "weeks": [
            {"id": 2, "position": 1, "workouts": [
              {"id": 2, "day": 1, "name": "Upper A", "volume_sets": {"Back": 3, "Chest": 3}},
              {"id": 3, "day": 3, "name": "Lower A", "volume_sets": {"Hamstrings": 3, "Quadriceps": 3}}
            ]},
            {"id": 3, "position": 2, "workouts": [
              {"id": 4, "day": 1, "name": "Upper B", "volume_sets": {"Back": 3, "Chest": 3}},
              {"id": 5, "day": 4, "name": "Arms & Shoulders", "volume_sets": {"Biceps": 3, "Shoulders": 3}}
            ]}
          ],
          "assignment_id": 1
        }
        """

        private static let sessionsJSON = """
        [
          {
            "id": 2,
            "completed_at": "2026-09-08T11:45:00.000Z",
            "notes": null,
            "started_at": "2026-09-08T11:00:00.000Z",
            "workout_id": 3
          },
          {
            "id": 1,
            "completed_at": "2026-09-06T19:05:00.000Z",
            "notes": null,
            "started_at": "2026-09-06T18:00:00.000Z",
            "workout_id": 2
          }
        ]
        """

        private static let resumeJSON = """
        {"id":3,"completed_at":null,"notes":null,"started_at":"2026-09-09T16:15:00.000Z","workout_id":4}
        """
    }

    #Preview("Home — next workout") {
        NavigationStack { HomeDesignPreview() }
            .tint(LacticColor.accent)
    }
#endif
