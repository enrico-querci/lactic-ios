import Foundation
import LacticCore

/// A client-generated identifier for a record the server has not seen yet.
///
/// Set logging is two levels deep — a set belongs to an exercise log, which
/// belongs to a session — so a set created offline refers to a parent that has
/// no server id either. `LocalID` is what the outbox resolves those references
/// against once each create comes back.
public struct LocalID: Hashable, Codable, Sendable, CustomStringConvertible {
    private let raw: UUID

    public init() {
        raw = UUID()
    }

    public var description: String {
        raw.uuidString
    }
}

/// A reference to a record that may or may not exist on the server yet.
public enum RecordRef: Hashable, Codable, Sendable {
    case server(Int)
    case local(LocalID)

    public var serverID: Int? {
        if case .server(let id) = self {
            return id
        }
        return nil
    }

    public var localID: LocalID? {
        if case .local(let id) = self {
            return id
        }
        return nil
    }
}

/// One write waiting to reach the server.
///
/// Stored rather than replayed from UI state: the whole point is that these
/// survive the app being killed mid-workout, which is routine when a phone is
/// in a pocket between sets.
public struct PendingOperation: Identifiable, Codable, Sendable, Equatable {
    public enum Kind: Codable, Sendable, Equatable {
        case createExerciseLog(localID: LocalID, sessionID: Int, workoutExerciseID: Int)
        case updateExerciseLog(log: RecordRef, notes: String?)
        case createSetLog(localID: LocalID, log: RecordRef, position: Int, weightKg: Decimal, reps: Int)
        case updateSetLog(set: RecordRef, weightKg: Decimal?, reps: Int?)
        case deleteSetLog(set: RecordRef)
        case updateSession(sessionID: Int, completedAt: Date?, notes: String?)
    }

    public let id: UUID
    public let kind: Kind
    /// Retries so far. Kept so backoff survives a relaunch rather than resetting
    /// to zero and hammering a server that is already struggling.
    public var attempts: Int
    /// Set when the server rejected this permanently. Such an operation is kept
    /// rather than dropped: the user needs telling that a set did not save, and
    /// silently discarding their work is the one outcome worth avoiding.
    public var failure: String?

    public init(kind: Kind) {
        id = UUID()
        self.kind = kind
        attempts = 0
        failure = nil
    }

    public var isBlocked: Bool {
        failure != nil
    }

    /// The local record this operation creates, if any.
    var producesLocalID: LocalID? {
        switch kind {
        case .createExerciseLog(let localID, _, _): localID
        case .createSetLog(let localID, _, _, _, _): localID
        default: nil
        }
    }

    /// The local record this operation depends on, if any. An operation whose
    /// dependency is unresolved cannot be sent yet.
    var dependsOn: LocalID? {
        switch kind {
        case .createSetLog(_, let log, _, _, _): log.localID
        case .updateExerciseLog(let log, _): log.localID
        case .updateSetLog(let set, _, _), .deleteSetLog(let set): set.localID
        default: nil
        }
    }
}
