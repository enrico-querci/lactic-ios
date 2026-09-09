#if DEBUG
    import LacticCore
    import LacticKit
    import LacticUI
    import SwiftUI

    /// Exercises the production components with synthetic data and no network
    /// or persisted writes. Available in the gallery and via a launch argument.
    struct WorkoutDesignPreview: View {
        @State private var fixture: WorkoutDesignFixture?
        @State private var errorMessage: String?
        @State private var deadline: Date? = Date().addingTimeInterval(85)

        var body: some View {
            ScrollView {
                VStack(spacing: LacticSpacing.lg) {
                    if ProcessInfo.processInfo.arguments.contains("--workout-design-timer") {
                        RestTimerView(duration: 90, deadline: $deadline)
                    } else if let fixture {
                        WorkoutOverviewHeader(
                            name: "Lower body strength", exerciseCount: 2, targetSets: 6,
                            loggedSets: fixture.recorder.entries.values.reduce(0) { $0 + $1.sets.count }
                        )
                        ExerciseCard(
                            workoutExercise: fixture.exercise,
                            recorder: fixture.recorder,
                            lastTime: nil,
                            locale: .english,
                            animationLoader: { throw URLError(.notConnectedToInternet) }
                        )
                    } else if let errorMessage {
                        Text(errorMessage)
                    }
                }
                .padding(LacticSpacing.lg)
            }
            .background(LacticColor.surface)
            .navigationTitle("Workout preview")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                do {
                    fixture = try WorkoutDesignFixture()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    private struct WorkoutDesignFixture {
        let exercise: WorkoutExercise
        let recorder: WorkoutRecorder

        init() throws {
            exercise = try JSONCoding.decoder.decode(WorkoutExercise.self, from: Data(Self.exerciseJSON.utf8))
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [WorkoutPreviewProtocol.self]
            let client = APIClient(
                configuration: .localDevelopment(locale: { "en" }),
                session: URLSession(configuration: configuration)
            )
            recorder = WorkoutRecorder(sessionID: 1, outbox: Outbox(client: client, store: PreviewOutboxStore()))
            try recorder.hydrate(from: JSONCoding.decoder.decode(
                WorkoutSessionDetail.self, from: Data(Self.sessionJSON.utf8)
            ))
        }

        private static let exerciseJSON = """
        {
          "id": 7, "position": "A", "sets": 3, "reps": 8, "rest_seconds": 90,
          "rir": 2, "weight": "72.5", "notes": "Keep the tempo controlled on the way down.",
          "exercise": {
            "id": 145, "name": "Barbell back squat", "muscle_group": "Quadriceps",
            "is_custom": false, "has_animation": false, "prescription_type": "repetitions",
            "active": true, "assignable": true, "equipment": []
          }
        }
        """

        private static let sessionJSON = """
        {
          "id": 1, "workout_id": 3, "started_at": "2026-09-09T10:00:00Z",
          "completed_at": null, "notes": null,
          "exercise_logs": [{
            "id": 1, "workout_exercise_id": 7, "notes": null, "photo_url": null,
            "set_logs": [
              {"id": 1, "position": 1, "weight_kg": "72.5", "reps": 8},
              {"id": 2, "position": 2, "weight_kg": "72.5", "reps": 7}
            ]
          }]
        }
        """
    }

    private struct PreviewOutboxStore: OutboxStoring {
        func load() throws -> OutboxState {
            OutboxState()
        }

        func save(_: OutboxState) throws {}
    }

    private final class WorkoutPreviewProtocol: URLProtocol, @unchecked Sendable {
        override class func canInit(with _: URLRequest) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        }

        override func stopLoading() {}
    }

    #Preview("Workout execution") {
        NavigationStack { WorkoutDesignPreview() }
            .tint(LacticColor.accent)
    }
#endif
