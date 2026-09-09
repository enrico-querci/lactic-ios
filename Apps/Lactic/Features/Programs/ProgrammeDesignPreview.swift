#if DEBUG
    import Foundation
    import LacticCore
    import LacticKit
    import LacticUI
    import SwiftUI

    struct ProgrammeDesignPreview: View {
        enum Mode: Equatable {
            case detail
            case list
        }

        private let mode: Mode
        @State private var fixture: Fixture?
        @State private var errorMessage: String?

        init(mode: Mode? = nil) {
            self.mode = mode ?? (ProcessInfo.processInfo.arguments.contains("--programme-list") ? .list : .detail)
        }

        var body: some View {
            Group {
                if let fixture {
                    switch mode {
                    case .detail:
                        ProgramPlanView(snapshot: fixture.snapshot, locale: .english)
                    case .list:
                        ProgramsDashboard(assignments: fixture.assignments, locale: .english)
                    }
                } else if let errorMessage {
                    Text(errorMessage)
                } else {
                    ProgressView()
                }
            }
            .background(LacticColor.surface)
            .navigationTitle(mode == .list ? Text("Programmes") : Text("Upper / Lower Strength"))
            .task {
                do {
                    fixture = try Self.makeFixture()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }

        private static func makeFixture() throws -> Fixture {
            let assignments = try JSONCoding.decoder.decode(
                [ProgramAssignment].self,
                from: Data(assignmentsJSON.utf8)
            )
            let program = try JSONCoding.decoder.decode(ProgramDetail.self, from: Data(programJSON.utf8))
            let sessions = try JSONCoding.decoder.decode([WorkoutSession].self, from: Data(sessionsJSON.utf8))
            return Fixture(
                assignments: assignments,
                snapshot: ProgramDetailModel.Snapshot(program: program, sessions: sessions)
            )
        }

        private struct Fixture {
            let assignments: [ProgramAssignment]
            let snapshot: ProgramDetailModel.Snapshot
        }

        private static let assignmentsJSON = """
        [
          {
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
              "description": "Two-week upper/lower split for strength and clean technique.",
              "name": "Upper / Lower Strength"
            },
            "start_date": "2026-09-01",
            "status": "active"
          },
          {
            "id": 2,
            "client": {
              "id": 4,
              "avatar_url": null,
              "email": "alice@example.com",
              "name": "Alice Client",
              "role": "client"
            },
            "notes": null,
            "program": {
              "id": 8,
              "created_at": "2026-09-08T10:56:02.650Z",
              "description": "Short mobility sessions for recovery days.",
              "name": "Recovery & Mobility"
            },
            "start_date": "2026-09-15",
            "status": "active"
          }
        ]
        """

        private static let programJSON = """
        {
          "id": 2,
          "created_at": "2026-09-08T10:56:02.650Z",
          "description": "Two-week upper/lower split for strength and clean technique.",
          "name": "Upper / Lower Strength",
          "weeks": [
            {"id": 2, "position": 1, "workouts": [
              {"id": 2, "day": 1, "name": "Upper A", "volume_sets": {"Back": 6, "Chest": 6}},
              {"id": 3, "day": 3, "name": "Lower A", "volume_sets": {"Hamstrings": 4, "Quadriceps": 8}}
            ]},
            {"id": 3, "position": 2, "workouts": [
              {"id": 4, "day": 1, "name": "Upper B", "volume_sets": {"Back": 6, "Chest": 6}},
              {"id": 5, "day": 4, "name": "Arms & Shoulders", "volume_sets": {"Biceps": 6, "Shoulders": 6}}
            ]}
          ],
          "assignment_id": 1
        }
        """

        private static let sessionsJSON = """
        [
          {
            "id": 1,
            "completed_at": "2026-09-06T19:05:00.000Z",
            "notes": null,
            "started_at": "2026-09-06T18:00:00.000Z",
            "workout_id": 2
          },
          {
            "id": 2,
            "completed_at": null,
            "notes": null,
            "started_at": "2026-09-09T16:15:00.000Z",
            "workout_id": 4
          }
        ]
        """
    }

    #Preview("Programme detail") {
        NavigationStack { ProgrammeDesignPreview(mode: .detail) }
            .tint(LacticColor.accent)
    }
#endif
