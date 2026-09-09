import Foundation
import LacticCore

/// Sends queued writes to the server, in order, surviving restarts.
///
/// An actor because it is the single writer of the queue: a drain triggered by
/// reachability must not interleave with one triggered by the user logging
/// another set.
public actor Outbox {
    public struct Progress: Sendable, Equatable {
        public var pending: Int
        public var blocked: Int
        public var isDraining: Bool

        public var isSettled: Bool {
            pending == 0 && !isDraining
        }
    }

    private let client: APIClient
    private let store: any OutboxStoring
    private var state: OutboxState
    private var isDraining = false
    /// Retry delays, in seconds. Capped rather than unbounded: a phone in a
    /// gym basement should keep trying at a sensible interval, not back off to
    /// once an hour and appear broken when signal returns.
    private let backoff: [Duration] = [.seconds(1), .seconds(3), .seconds(8), .seconds(20), .seconds(45)]
    private let maximumAttempts = 8

    private var observers: [UUID: @Sendable (Progress) -> Void] = [:]

    public init(client: APIClient, store: any OutboxStoring = FileOutboxStore()) {
        self.client = client
        self.store = store
        state = (try? store.load()) ?? OutboxState()
    }

    // MARK: - Queue

    public var progress: Progress {
        Progress(pending: state.pending.count, blocked: state.blocked.count, isDraining: isDraining)
    }

    /// Everything the server has rejected outright, for the UI to surface.
    public var blockedOperations: [PendingOperation] {
        state.blocked
    }

    public func observe(_ observer: @escaping @Sendable (Progress) -> Void) -> UUID {
        let token = UUID()
        observers[token] = observer
        observer(progress)
        return token
    }

    public func removeObserver(_ token: UUID) {
        observers[token] = nil
    }

    /// Queues a write and persists it **before** returning, so a crash between
    /// the user's tap and the network call cannot lose it.
    @discardableResult
    public func enqueue(_ kind: PendingOperation.Kind) -> PendingOperation {
        let operation = PendingOperation(kind: kind)
        state.operations.append(operation)
        // Remember the session while the operation that names it is still here;
        // it is removed once it succeeds.
        switch kind {
        case .createExerciseLog(_, let sessionID, _), .updateSession(let sessionID, _, _):
            state.sessionID = sessionID
        default:
            break
        }
        persist()
        return operation
    }

    /// The server id for a locally created record, once it has one.
    public func serverID(for localID: LocalID) -> Int? {
        state.resolved[localID]
    }

    public func discardBlocked() {
        state.operations.removeAll(where: \.isBlocked)
        persist()
    }

    // MARK: - Draining

    /// Sends everything it can, oldest first, stopping at the first operation
    /// that cannot proceed.
    ///
    /// Strictly ordered rather than parallel. A set create depends on its
    /// exercise log's server id, and sets within a log are positioned, so
    /// sending them concurrently would race the dependency and scramble the
    /// order the trainee actually performed.
    public func drain() async {
        guard !isDraining else { return }
        isDraining = true
        notify()
        defer {
            isDraining = false
            notify()
        }

        while let operation = nextSendable() {
            do {
                try await send(operation)
                remove(operation)
            } catch let error as APIError where !error.isRetryable {
                if let recovered = await reconcile(operation, after: error) {
                    resolve(operation, to: recovered)
                    remove(operation)
                } else {
                    block(operation, reason: error.message)
                }
            } catch {
                guard bumpAttempts(operation) else {
                    block(operation, reason: (error as? APIError)?.message ?? error.localizedDescription)
                    continue
                }
                // Wait, then let the next drain pick it up. Returning rather
                // than looping keeps a single slow failure from blocking every
                // later operation indefinitely.
                try? await Task.sleep(for: delay(for: operation))
                return
            }
        }
    }

    /// The oldest operation whose dependency is satisfied.
    private func nextSendable() -> PendingOperation? {
        state.pending.first { operation in
            guard let dependency = operation.dependsOn else { return true }
            return state.resolved[dependency] != nil
        }
    }

    private func send(_ operation: PendingOperation) async throws {
        switch operation.kind {
        case .createExerciseLog(let localID, let sessionID, let workoutExerciseID):
            let log: ExerciseLog = try await client.send(
                ClientAPI.createExerciseLog(
                    workoutSessionID: sessionID, workoutExerciseID: workoutExerciseID
                )
            )
            state.resolved[localID] = log.id

        case .updateExerciseLog(let ref, let notes):
            guard let id = resolvedID(ref) else { throw APIError.sessionExpired }
            _ = try await client.send(
                ClientAPI.updateExerciseLog(id: id, notes: notes), as: ExerciseLog.self
            )

        case .createSetLog(let localID, let ref, let position, let weightKg, let reps):
            guard let logID = resolvedID(ref) else { throw APIError.sessionExpired }
            let set: SetLog = try await client.send(
                ClientAPI.createSetLog(
                    exerciseLogID: logID, position: position, weightKg: weightKg, reps: reps
                )
            )
            state.resolved[localID] = set.id

        case .updateSetLog(let ref, let weightKg, let reps):
            guard let id = resolvedID(ref) else { throw APIError.sessionExpired }
            _ = try await client.send(
                ClientAPI.updateSetLog(id: id, weightKg: weightKg, reps: reps), as: SetLog.self
            )

        case .deleteSetLog(let ref):
            guard let id = resolvedID(ref) else { throw APIError.sessionExpired }
            try await client.sendIgnoringResponse(ClientAPI.deleteSetLog(id: id))

        case .updateSession(let sessionID, let completedAt, let notes):
            _ = try await client.send(
                ClientAPI.updateSession(id: sessionID, completedAt: completedAt, notes: notes),
                as: WorkoutSession.self
            )
        }
    }

    /// Recovers from a rejection that actually means "already done".
    ///
    /// `set_logs` has a unique index on `(exercise_log_id, position)`, so a
    /// create replayed after an ambiguous failure — request sent, response
    /// lost — comes back 422 "Position has already been taken" rather than
    /// inserting a duplicate. That constraint is the closest thing the API
    /// offers to an idempotency key, and treating it as a plain failure would
    /// strand a set that is in fact saved.
    ///
    /// Re-reads the log and adopts the existing row instead.
    private func reconcile(_ operation: PendingOperation, after error: APIError) async -> Int? {
        guard case .createSetLog(_, let ref, let position, _, _) = operation.kind,
              error.status == 422,
              error.message.localizedCaseInsensitiveContains("position"),
              let logID = resolvedID(ref)
        else { return nil }

        // The set endpoints have no "show", so the session is the way back to
        // an existing row. Failing here leaves the operation blocked, which is
        // the safe direction: reported rather than silently dropped.
        guard let sessionID = state.sessionID,
              let session: WorkoutSessionDetail = try? await client.send(
                  ClientAPI.workoutSession(id: sessionID)
              ),
              let log = session.exerciseLogs.first(where: { $0.id == logID }),
              let existing = log.setLogs.first(where: { $0.position == position })
        else { return nil }

        AppLog.outbox.info("Adopted an existing set at position \(position) after a duplicate create")
        return existing.id
    }

    private func resolvedID(_ ref: RecordRef) -> Int? {
        switch ref {
        case .server(let id): id
        case .local(let localID): state.resolved[localID]
        }
    }

    // MARK: - Queue mutation

    private func remove(_ operation: PendingOperation) {
        state.operations.removeAll { $0.id == operation.id }
        persist()
    }

    private func resolve(_ operation: PendingOperation, to serverID: Int) {
        if let localID = operation.producesLocalID {
            state.resolved[localID] = serverID
        }
    }

    private func block(_ operation: PendingOperation, reason: String) {
        guard let index = state.operations.firstIndex(where: { $0.id == operation.id }) else { return }
        state.operations[index].failure = reason
        AppLog.outbox.error("Operation permanently rejected: \(reason, privacy: .public)")
        persist()
    }

    /// Returns false once an operation has been retried too many times.
    private func bumpAttempts(_ operation: PendingOperation) -> Bool {
        guard let index = state.operations.firstIndex(where: { $0.id == operation.id }) else { return false }
        state.operations[index].attempts += 1
        persist()
        return state.operations[index].attempts < maximumAttempts
    }

    private func delay(for operation: PendingOperation) -> Duration {
        let attempts = state.operations.first { $0.id == operation.id }?.attempts ?? 0
        return backoff[min(max(attempts - 1, 0), backoff.count - 1)]
    }

    private func persist() {
        try? store.save(state)
        notify()
    }

    private func notify() {
        let snapshot = progress
        for observer in observers.values {
            observer(snapshot)
        }
    }
}
