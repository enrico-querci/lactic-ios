import Foundation
import LacticCore
import Observation

/// A workout in progress.
///
/// Every action updates the in-memory session immediately and queues the write,
/// rather than waiting for the server. The trainee is mid-set with a phone in
/// one hand; a spinner between tapping "done" and seeing the set appear is the
/// difference between an app you can use in a gym and one you cannot.
///
/// The queue is durable, so the optimism is safe: nothing is shown as saved
/// that is not at least recorded somewhere that survives the app being killed.
@MainActor
@Observable
public final class WorkoutRecorder {
    /// One performed set, as the screen sees it.
    public struct Set: Identifiable, Sendable, Equatable {
        public let id: LocalID
        public var position: Int
        public var weightKg: Decimal
        public var reps: Int
        /// Set once the server has accepted it.
        public var serverID: Int?
    }

    /// One exercise's logged sets.
    public struct ExerciseEntry: Identifiable, Sendable, Equatable {
        public let id: LocalID
        public let workoutExerciseID: Int
        public var notes: String?
        public var sets: [Set]
        public var serverID: Int?

        public var orderedSets: [Set] {
            sets.sorted { $0.position < $1.position }
        }
    }

    public private(set) var sessionID: Int
    public private(set) var entries: [Int: ExerciseEntry] = [:]
    public private(set) var notes: String?
    public private(set) var completedAt: Date?
    public private(set) var syncProgress = Outbox.Progress(pending: 0, blocked: 0, isDraining: false)

    private let outbox: Outbox
    private var observerToken: UUID?

    public init(sessionID: Int, outbox: Outbox) {
        self.sessionID = sessionID
        self.outbox = outbox
    }

    /// Adopts what the server already has, so a session resumed after the app
    /// was killed shows the sets that were logged before.
    public func hydrate(from detail: WorkoutSessionDetail) {
        notes = detail.notes
        completedAt = detail.completedAt
        for log in detail.exerciseLogs {
            let entry = ExerciseEntry(
                id: LocalID(),
                workoutExerciseID: log.workoutExerciseID,
                notes: log.notes,
                sets: log.orderedSets.map {
                    Set(id: LocalID(), position: $0.position, weightKg: $0.weightKg, reps: $0.reps, serverID: $0.id)
                },
                serverID: log.id
            )
            entries[log.workoutExerciseID] = entry
        }
    }

    public func startObservingSync() async {
        observerToken = await outbox.observe { [weak self] progress in
            Task { @MainActor [weak self] in self?.syncProgress = progress }
        }
    }

    public func stopObservingSync() async {
        if let observerToken {
            await outbox.removeObserver(observerToken)
        }
        observerToken = nil
    }

    // MARK: - Logging

    /// Adds a set, pre-filled from the coach's prescription.
    ///
    /// **Never zeros.** The API rejects `reps <= 0`, so a set added with empty
    /// values fails validation and the trainee cannot add a set at all — the
    /// exact bug the web hit. The target is the sensible starting point anyway:
    /// it is what they were asked to do, and they edit down to what they
    /// managed.
    @discardableResult
    public func addSet(to workoutExercise: WorkoutExercise) async -> Set {
        let entry = await ensureEntry(for: workoutExercise)
        let position = (entries[workoutExercise.id]?.sets.map(\.position).max() ?? 0) + 1

        let set = Set(
            id: LocalID(),
            position: position,
            weightKg: workoutExercise.weight ?? 0,
            reps: max(workoutExercise.reps, 1),
            serverID: nil
        )
        entries[workoutExercise.id]?.sets.append(set)

        await outbox.enqueue(.createSetLog(
            localID: set.id,
            log: entry.serverID.map { RecordRef.server($0) } ?? .local(entry.id),
            position: set.position,
            weightKg: set.weightKg,
            reps: set.reps
        ))
        await drain()
        return set
    }

    public func updateSet(_ setID: LocalID, in workoutExerciseID: Int, weightKg: Decimal?, reps: Int?) async {
        guard var entry = entries[workoutExerciseID],
              let index = entry.sets.firstIndex(where: { $0.id == setID })
        else { return }

        if let weightKg {
            entry.sets[index].weightKg = weightKg
        }
        if let reps {
            entry.sets[index].reps = reps
        }
        let set = entry.sets[index]
        entries[workoutExerciseID] = entry

        await outbox.enqueue(.updateSetLog(
            set: set.serverID.map { RecordRef.server($0) } ?? .local(set.id),
            weightKg: weightKg,
            reps: reps
        ))
        await drain()
    }

    public func deleteSet(_ setID: LocalID, in workoutExerciseID: Int) async {
        guard var entry = entries[workoutExerciseID],
              let index = entry.sets.firstIndex(where: { $0.id == setID })
        else { return }

        let set = entry.sets.remove(at: index)
        entries[workoutExerciseID] = entry

        await outbox.enqueue(.deleteSetLog(
            set: set.serverID.map { RecordRef.server($0) } ?? .local(set.id)
        ))
        await drain()
    }

    public func setNotes(_ text: String?, for workoutExercise: WorkoutExercise) async {
        let entry = await ensureEntry(for: workoutExercise)
        entries[workoutExercise.id]?.notes = text

        await outbox.enqueue(.updateExerciseLog(
            log: entry.serverID.map { RecordRef.server($0) } ?? .local(entry.id),
            notes: text
        ))
        await drain()
    }

    public func setSessionNotes(_ text: String?) async {
        notes = text
        await outbox.enqueue(.updateSession(sessionID: sessionID, completedAt: completedAt, notes: text))
        await drain()
    }

    public func complete(at date: Date = Date()) async {
        completedAt = date
        await outbox.enqueue(.updateSession(sessionID: sessionID, completedAt: date, notes: notes))
        await drain()
    }

    // MARK: - Internals

    /// Creates the exercise log lazily, on the first set for that exercise.
    ///
    /// Matches the API's shape: a set belongs to a log, and creating logs up
    /// front would leave empty ones for every exercise the trainee skipped.
    private func ensureEntry(for workoutExercise: WorkoutExercise) async -> ExerciseEntry {
        if let existing = entries[workoutExercise.id] {
            return existing
        }

        let entry = ExerciseEntry(
            id: LocalID(),
            workoutExerciseID: workoutExercise.id,
            notes: nil,
            sets: [],
            serverID: nil
        )
        entries[workoutExercise.id] = entry

        await outbox.enqueue(.createExerciseLog(
            localID: entry.id, sessionID: sessionID, workoutExerciseID: workoutExercise.id
        ))
        return entry
    }

    /// Drains in the background: the caller is a UI action and must not wait on
    /// the network.
    private func drain() async {
        let outbox = outbox
        Task.detached { await outbox.drain() }
        await adoptResolvedIDs()
    }

    /// Copies server ids back onto the in-memory records once the outbox has
    /// them, so a later edit addresses the real row rather than a local id.
    private func adoptResolvedIDs() async {
        for (workoutExerciseID, entry) in entries {
            var updated = entry
            if updated.serverID == nil {
                updated.serverID = await outbox.serverID(for: entry.id)
            }
            for index in updated.sets.indices where updated.sets[index].serverID == nil {
                updated.sets[index].serverID = await outbox.serverID(for: updated.sets[index].id)
            }
            entries[workoutExerciseID] = updated
        }
    }
}
