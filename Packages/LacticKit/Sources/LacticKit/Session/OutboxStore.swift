import Foundation
import LacticCore

/// Where the outbox keeps its queue between launches.
public protocol OutboxStoring: Sendable {
    func load() throws -> OutboxState
    func save(_ state: OutboxState) throws
}

/// The queue plus what it has learned about server ids so far.
public struct OutboxState: Codable, Sendable, Equatable {
    public var operations: [PendingOperation]
    /// Local ids that have been created server-side, and what they became.
    public var resolved: [LocalID: Int]
    /// The session these writes belong to.
    ///
    /// Held here rather than derived from the queue: a successful operation is
    /// removed, so by the time a later set create needs to reconcile against
    /// the server there may be nothing left carrying the id. Only one workout
    /// is ever in progress, so a single value is unambiguous.
    public var sessionID: Int?

    public init(
        operations: [PendingOperation] = [],
        resolved: [LocalID: Int] = [:],
        sessionID: Int? = nil
    ) {
        self.operations = operations
        self.resolved = resolved
        self.sessionID = sessionID
    }

    public var isEmpty: Bool {
        operations.isEmpty
    }

    /// Operations still worth attempting — a permanently rejected one stays in
    /// the queue so it can be reported, but must not be retried.
    public var pending: [PendingOperation] {
        operations.filter { !$0.isBlocked }
    }

    public var blocked: [PendingOperation] {
        operations.filter(\.isBlocked)
    }
}

/// Persists the queue to a JSON file in the app container.
///
/// Written atomically, because the failure this exists to survive is the app
/// being killed — including partway through a save. A half-written queue would
/// lose exactly the work it was meant to protect.
///
/// Excluded from backup: the queue is transient state whose records live on the
/// server within seconds, and restoring a stale one onto a new device would
/// replay writes that already happened.
public struct FileOutboxStore: OutboxStoring {
    private let url: URL

    public init(filename: String = "workout-outbox.json") {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent(filename)
    }

    public func load() throws -> OutboxState {
        guard FileManager.default.fileExists(atPath: url.path) else { return OutboxState() }
        let data = try Data(contentsOf: url)
        // A corrupt queue is discarded rather than thrown: it would otherwise
        // wedge every future write behind a file nobody can read.
        return (try? JSONCoding.decoder.decode(OutboxState.self, from: data)) ?? OutboxState()
    }

    public func save(_ state: OutboxState) throws {
        let data = try JSONCoding.encoder.encode(state)
        try data.write(to: url, options: .atomic)

        var resource = URLResourceValues()
        resource.isExcludedFromBackup = true
        var mutable = url
        try? mutable.setResourceValues(resource)
    }
}

/// An in-memory store, for tests and previews.
public final class InMemoryOutboxStore: OutboxStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var state: OutboxState

    public init(_ state: OutboxState = OutboxState()) {
        self.state = state
    }

    public func load() throws -> OutboxState {
        lock.withLock { state }
    }

    public func save(_ state: OutboxState) throws {
        lock.withLock { self.state = state }
    }
}
