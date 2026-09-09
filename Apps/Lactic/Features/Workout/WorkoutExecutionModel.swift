import Foundation
import LacticKit
import LacticUI
import Observation

/// Drives one workout: finding or starting its session, and logging into it.
@MainActor
@Observable
final class WorkoutExecutionModel: LoadableSource {
    struct Context: Sendable, Equatable {
        let workout: WorkoutDetail
        /// The client's most recent set for each exercise, for the "last time"
        /// prompt. Keyed by exercise id, not workout-exercise id, so it carries
        /// across programmes.
        var lastTime: [Int: SetLog]
    }

    private(set) var state: Loadable<Context> = .idle
    private(set) var recorder: WorkoutRecorder?
    private(set) var actionError: String?
    private(set) var isStarting = false

    private let client: APIClient
    private let outbox: Outbox
    private let workoutID: Int
    private let assignmentID: Int

    init(client: APIClient, outbox: Outbox, workoutID: Int, assignmentID: Int) {
        self.client = client
        self.outbox = outbox
        self.workoutID = workoutID
        self.assignmentID = assignmentID
    }

    var isSessionActive: Bool {
        recorder != nil
    }

    func load() async {
        if case .loaded = state {
            return
        }
        await reload()
    }

    func reload() async {
        state = .loading
        do {
            let workout: WorkoutDetail = try await client.send(ClientAPI.workout(id: workoutID))

            // Resume before offering to start. A session left open is the
            // normal case when the app was killed mid-workout, and starting a
            // second one would split the same workout across two records.
            await resumeExistingSession()

            state = .loaded(Context(workout: workout, lastTime: [:]))
            await loadLastTime(for: workout)
        } catch {
            state = .failed((error as? APIError)?.message ?? error.localizedDescription)
        }
    }

    /// Starts a session, or adopts the one already in progress.
    func start() async {
        guard recorder == nil else { return }
        isStarting = true
        defer { isStarting = false }

        do {
            let session: WorkoutSession = try await client.send(
                ClientAPI.startSession(
                    workoutID: workoutID, programAssignmentID: assignmentID, startedAt: Date()
                )
            )
            let recorder = WorkoutRecorder(sessionID: session.id, outbox: outbox)
            await recorder.startObservingSync()
            self.recorder = recorder
        } catch {
            actionError = (error as? APIError)?.message ?? error.localizedDescription
        }
    }

    func complete() async {
        guard let recorder else { return }
        await recorder.complete()
        await recorder.stopObservingSync()
        self.recorder = nil
    }

    func dismissError() {
        actionError = nil
    }

    /// Fetches the demonstration's bytes for one exercise. Authenticated and
    /// metered, so only called when the user opens the demonstration.
    func animationLoader(exerciseID: Int) -> @Sendable () async throws -> Data {
        let client = client
        return { try await client.data(for: ClientAPI.animation(exerciseID: exerciseID)) }
    }

    // MARK: - Internals

    private func resumeExistingSession() async {
        guard let sessions: [WorkoutSession] = try? await client.send(ClientAPI.workoutSessions),
              let open = sessions.first(where: { $0.workoutID == workoutID && $0.isInProgress })
        else { return }

        let recorder = WorkoutRecorder(sessionID: open.id, outbox: outbox)
        // Adopt whatever was already logged, so a resumed workout shows the
        // sets that were recorded before the app died rather than an empty one.
        if let detail: WorkoutSessionDetail = try? await client.send(
            ClientAPI.workoutSession(id: open.id)
        ) {
            recorder.hydrate(from: detail)
        }
        await recorder.startObservingSync()
        self.recorder = recorder
    }

    /// The single most useful number mid-set: what they lifted last time.
    ///
    /// The history endpoint returns a flat list ordered newest session first,
    /// so the first element is the most recent set. It carries no dates, so
    /// nothing more specific than "last time" can be said about it.
    private func loadLastTime(for workout: WorkoutDetail) async {
        var lastTime: [Int: SetLog] = [:]
        await withTaskGroup(of: (Int, SetLog?).self) { group in
            for entry in workout.workoutExercises {
                let exerciseID = entry.exercise.id
                group.addTask { [client] in
                    let history: [SetLog]? = try? await client.send(
                        ClientAPI.exerciseHistory(id: exerciseID)
                    )
                    return (exerciseID, history?.first)
                }
            }
            for await (exerciseID, set) in group {
                if let set {
                    lastTime[exerciseID] = set
                }
            }
        }
        guard case .loaded(let context) = state else { return }
        state = .loaded(Context(workout: context.workout, lastTime: lastTime))
    }
}
