#if DEBUG
    import Foundation
    import LacticCore
    import LacticKit
    import LacticUI
    import SwiftUI

    struct HistoryDesignPreview: View {
        enum Mode: Equatable {
            case history
            case session
            case exercise
        }

        private let mode: Mode
        @State private var fixture: Fixture?
        @State private var errorMessage: String?

        init(mode: Mode? = nil) {
            if let mode {
                self.mode = mode
            } else if ProcessInfo.processInfo.arguments.contains("--history-session") {
                self.mode = .session
            } else if ProcessInfo.processInfo.arguments.contains("--history-exercise") {
                self.mode = .exercise
            } else {
                self.mode = .history
            }
        }

        var body: some View {
            Group {
                if let fixture {
                    content(fixture)
                } else if let errorMessage {
                    Text(errorMessage)
                } else {
                    ProgressView()
                }
            }
            .background(LacticColor.surface)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(mode == .history ? .large : .inline)
            .task {
                do {
                    fixture = try Self.makeFixture()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }

        @ViewBuilder
        private func content(_ fixture: Fixture) -> some View {
            switch mode {
            case .history:
                HistoryDashboard(snapshot: fixture.history, locale: .english)
            case .session:
                SessionSummaryView(detail: fixture.session, locale: .english)
            case .exercise:
                ExerciseProgressView(
                    detail: fixture.exercise,
                    locale: .english,
                    cacheKey: "history-preview-exercise",
                    animationLoader: { Data() }
                )
            }
        }

        private var title: String {
            switch mode {
            case .history: String(localized: "History")
            case .session: "Lower Body Strength"
            case .exercise: "Back Squat"
            }
        }

        private static func makeFixture() throws -> Fixture {
            let sessions = try JSONCoding.decoder.decode([WorkoutSession].self, from: Data(sessionsJSON.utf8))
            let session = try JSONCoding.decoder.decode(WorkoutSessionDetail.self, from: Data(sessionJSON.utf8))
            let exercise = try JSONCoding.decoder.decode(ExerciseDetail.self, from: Data(exerciseJSON.utf8))
            let exerciseHistory = try JSONCoding.decoder.decode([SetLog].self, from: Data(exerciseHistoryJSON.utf8))

            let references = Dictionary(
                uniqueKeysWithValues: session.exerciseLogs.map { log in
                    (
                        log.workoutExerciseID,
                        SessionDetailModel.ExerciseReference(
                            exerciseID: log.exerciseID,
                            name: log.exerciseName,
                            position: log.position
                        )
                    )
                }
            )

            return Fixture(
                history: HistoryModel.Snapshot(sessions: sessions),
                session: SessionDetailModel.Detail(
                    session: session,
                    workoutName: session.workoutName,
                    exerciseReferences: references
                ),
                exercise: ExerciseDetailModel.Detail(exercise: exercise, history: exerciseHistory)
            )
        }

        private struct Fixture {
            let history: HistoryModel.Snapshot
            let session: SessionDetailModel.Detail
            let exercise: ExerciseDetailModel.Detail
        }

        // swiftlint:disable line_length
        private static let sessionsJSON = """
        [
          {"id":15,"workout_id":12,"workout_name":"Upper Body Power","started_at":"2026-09-10T16:10:00.000Z","completed_at":null,"notes":"Finish the final set after work."},
          {"id":14,"workout_id":11,"workout_name":"Lower Body Strength","started_at":"2026-09-08T17:30:00.000Z","completed_at":"2026-09-08T18:38:00.000Z","notes":"Depth felt strong. Add 2.5 kg next week."},
          {"id":13,"workout_id":10,"workout_name":"Pull & Core","started_at":"2026-09-05T07:20:00.000Z","completed_at":"2026-09-05T08:12:00.000Z","notes":null},
          {"id":12,"workout_id":11,"workout_name":"Lower Body Strength","started_at":"2026-09-01T17:35:00.000Z","completed_at":"2026-09-01T18:37:00.000Z","notes":"Controlled tempo throughout."}
        ]
        """

        private static let sessionJSON = """
        {
          "id":14,"workout_id":11,"workout_name":"Lower Body Strength",
          "started_at":"2026-09-08T17:30:00.000Z","completed_at":"2026-09-08T18:38:00.000Z",
          "notes":"Depth felt strong. Add 2.5 kg next week.",
          "exercise_logs":[
            {"id":31,"workout_exercise_id":21,"exercise_id":145,"exercise_name":"Back Squat","position":"A","notes":"Brace before every rep.","photo_url":null,"set_logs":[
              {"id":101,"position":1,"weight_kg":"75.0","reps":8},
              {"id":102,"position":2,"weight_kg":"77.5","reps":8},
              {"id":103,"position":3,"weight_kg":"80.0","reps":6}
            ]},
            {"id":32,"workout_exercise_id":22,"exercise_id":146,"exercise_name":"Romanian Deadlift","position":"B","notes":null,"photo_url":null,"set_logs":[
              {"id":104,"position":1,"weight_kg":"70.0","reps":10},
              {"id":105,"position":2,"weight_kg":"72.5","reps":10},
              {"id":106,"position":3,"weight_kg":"72.5","reps":9}
            ]}
          ]
        }
        """

        private static let exerciseJSON = """
        {
          "id":145,"active":true,"animation_url":null,"assignable":true,"category":"strength",
          "description":"A foundational lower-body movement for building strength through the quads, glutes, and trunk.",
          "difficulty":"intermediate","equipment":[{"key":"barbell","name":"Barbell"}],"force":"push",
          "has_animation":false,"instructions":["Set the bar across your upper back and brace your trunk.","Sit between your hips while keeping your whole foot planted.","Drive the floor away and finish tall."],
          "is_custom":false,"locale":"en","mechanic":"compound","muscle_group":"Quadriceps","name":"Back Squat",
          "prescription_type":"repetitions","primary_muscle":{"key":"quads","name":"Quadriceps","region":"Upper Legs"},
          "secondary_muscles":[{"key":"glutes","name":"Glutes"},{"key":"hamstrings","name":"Hamstrings"}],
          "thumbnail_url":null,"video_url":null
        }
        """

        private static let exerciseHistoryJSON = """
        [
          {"id":201,"position":1,"weight_kg":"75.0","reps":8,"workout_session_id":14,"performed_at":"2026-09-08T18:38:00.000Z"},
          {"id":202,"position":2,"weight_kg":"77.5","reps":8,"workout_session_id":14,"performed_at":"2026-09-08T18:38:00.000Z"},
          {"id":203,"position":3,"weight_kg":"80.0","reps":6,"workout_session_id":14,"performed_at":"2026-09-08T18:38:00.000Z"},
          {"id":191,"position":1,"weight_kg":"72.5","reps":8,"workout_session_id":12,"performed_at":"2026-09-01T18:37:00.000Z"},
          {"id":192,"position":2,"weight_kg":"75.0","reps":8,"workout_session_id":12,"performed_at":"2026-09-01T18:37:00.000Z"},
          {"id":181,"position":1,"weight_kg":"70.0","reps":10,"workout_session_id":9,"performed_at":"2026-08-25T18:42:00.000Z"}
        ]
        """
        // swiftlint:enable line_length
    }

    #Preview("History") {
        NavigationStack { HistoryDesignPreview(mode: .history) }
            .tint(LacticColor.accent)
    }

    #Preview("Session summary") {
        NavigationStack { HistoryDesignPreview(mode: .session) }
            .tint(LacticColor.accent)
    }

    #Preview("Exercise progress") {
        NavigationStack { HistoryDesignPreview(mode: .exercise) }
            .tint(LacticColor.accent)
    }
#endif
