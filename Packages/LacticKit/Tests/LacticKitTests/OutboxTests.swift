import Foundation
import LacticCore
import Testing
@testable import LacticKit

private func makeOutbox(
    store: any OutboxStoring = InMemoryOutboxStore(),
    handler: @escaping @Sendable (URLRequest) -> StubTransport.Response
) -> (Outbox, StubTransport) {
    let transport = StubTransport(handler: handler)
    let client = APIClient(
        configuration: APIConfiguration(baseURL: URL(string: "https://api.test")!) { "en" },
        session: transport.session
    )
    return (Outbox(client: client, store: store), transport)
}

private let exerciseLogBody = #"{"id":900,"notes":null,"photo_url":null,"workout_exercise_id":10}"#

private func setLogBody(id: Int, position: Int) -> String {
    #"{"id":\#(id),"position":\#(position),"reps":8,"weight_kg":"70.0"}"#
}

@Suite("Outbox")
struct OutboxTests {
    /// A set create depends on its exercise log's server id. Both are queued
    /// before either is sent, which is what happens when the first set of an
    /// exercise is logged with no signal.
    @Test func resolvesALocalDependencyBeforeSendingTheDependent() async {
        let (outbox, transport) = makeOutbox { request in
            request.url?.path.hasSuffix("/exercise_logs") == true
                ? .json(exerciseLogBody, status: 201)
                : .json(setLogBody(id: 501, position: 1), status: 201)
        }
        let logID = LocalID()

        await outbox.enqueue(.createExerciseLog(localID: logID, sessionID: 2, workoutExerciseID: 10))
        await outbox.enqueue(
            .createSetLog(localID: LocalID(), log: .local(logID), position: 1, weightKg: 70, reps: 8)
        )
        await outbox.drain()

        #expect(await outbox.progress.isSettled)
        #expect(await outbox.serverID(for: logID) == 900)
        #expect(transport.paths.count == 2)
        #expect(transport.paths[0].hasSuffix("/exercise_logs"), "the parent must be created first")
        #expect(transport.paths[1].hasSuffix("/set_logs"))
    }

    /// The queue is written before the network is touched, so work survives the
    /// app being killed between the tap and the request — routine when a phone
    /// goes back in a pocket between sets.
    @Test func survivesBeingKilledBeforeAnythingIsSent() async throws {
        let store = InMemoryOutboxStore()
        let logID = LocalID()

        do {
            let (outbox, _) = makeOutbox(store: store) { _ in .json("{}") }
            await outbox.enqueue(.createExerciseLog(localID: logID, sessionID: 2, workoutExerciseID: 10))
            await outbox.enqueue(
                .createSetLog(localID: LocalID(), log: .local(logID), position: 1, weightKg: 70, reps: 8)
            )
        } // The app dies here: nothing was drained.

        #expect(try store.load().operations.count == 2)

        let (relaunched, transport) = makeOutbox(store: store) { request in
            request.url?.path.hasSuffix("/exercise_logs") == true
                ? .json(exerciseLogBody, status: 201)
                : .json(setLogBody(id: 501, position: 1), status: 201)
        }
        await relaunched.drain()

        #expect(await relaunched.progress.isSettled)
        #expect(try store.load().isEmpty)
        #expect(transport.requests.count == 2, "both queued writes reached the server after relaunch")
    }

    /// A transport failure must not lose the write.
    @Test func keepsWorkQueuedWhenTheNetworkIsDown() async throws {
        let store = InMemoryOutboxStore()
        let (outbox, _) = makeOutbox(store: store) { _ in .json(#"{"error":"boom"}"#, status: 503) }

        await outbox.enqueue(.createExerciseLog(localID: LocalID(), sessionID: 2, workoutExerciseID: 10))
        await outbox.drain()

        #expect(await outbox.progress.pending == 1, "a 503 is retryable, so the work stays queued")
        #expect(await outbox.progress.blocked == 0)
        #expect(try store.load().operations.first?.attempts == 1, "the attempt count persists across launches")
    }

    /// The API rejects reps <= 0 outright. Retrying cannot help, and spinning on
    /// it would block every later set behind a write that will never succeed.
    @Test func blocksAWriteTheServerWillNeverAccept() async {
        let (outbox, _) = makeOutbox { _ in
            .json(#"{"errors":["Reps must be greater than 0"]}"#, status: 422)
        }
        await outbox.enqueue(
            .createSetLog(localID: LocalID(), log: .server(900), position: 1, weightKg: 70, reps: 0)
        )
        await outbox.drain()

        #expect(await outbox.progress.pending == 0)
        #expect(await outbox.progress.blocked == 1, "kept so the user can be told, not silently dropped")
        #expect(await outbox.blockedOperations.first?.failure == "Reps must be greater than 0")
    }

    /// The ambiguous case: the request reached the server and the response was
    /// lost, so the replay hits the unique index on (exercise_log_id, position).
    /// That 422 means "already saved", and the set must be adopted rather than
    /// reported as a failure.
    ///
    /// The log create succeeds and is removed from the queue first, which is
    /// what proved the session id has to be persisted in the state rather than
    /// read back out of the remaining operations.
    @Test func adoptsAnExistingSetWhenAReplayHitsTheUniqueIndex() async {
        let sessionBody = """
        {"id":2,"completed_at":null,"notes":null,"started_at":"2026-09-08T11:00:00.000Z",\
        "workout_id":3,"exercise_logs":[{"id":900,"notes":null,"photo_url":null,\
        "workout_exercise_id":10,"set_logs":[{"id":777,"position":1,"reps":8,"weight_kg":"70.0"}]}]}
        """
        let (outbox, _) = makeOutbox { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/exercise_logs") {
                return .json(exerciseLogBody, status: 201)
            }
            if path.hasSuffix("/set_logs") {
                return .json(#"{"errors":["Position has already been taken"]}"#, status: 422)
            }
            return .json(sessionBody)
        }
        let logID = LocalID()
        let setID = LocalID()

        await outbox.enqueue(.createExerciseLog(localID: logID, sessionID: 2, workoutExerciseID: 10))
        await outbox.enqueue(
            .createSetLog(localID: setID, log: .local(logID), position: 1, weightKg: 70, reps: 8)
        )
        await outbox.drain()

        #expect(await outbox.progress.blocked == 0, "a duplicate is not a failure")
        #expect(await outbox.progress.pending == 0)
        #expect(await outbox.serverID(for: setID) == 777, "adopted the row the server already had")
    }

    /// A 422 that is not the uniqueness constraint must still block.
    @Test func doesNotMistakeEveryValidationFailureForADuplicate() async {
        let (outbox, _) = makeOutbox { _ in
            .json(#"{"errors":["Weight kg must be greater than or equal to 0"]}"#, status: 422)
        }
        await outbox.enqueue(
            .createSetLog(localID: LocalID(), log: .server(900), position: 1, weightKg: -5, reps: 8)
        )
        await outbox.drain()

        #expect(await outbox.progress.blocked == 1)
    }

    @Test func sendsSetsInThePerformedOrder() async {
        let (outbox, transport) = makeOutbox { _ in .json(setLogBody(id: 501, position: 1), status: 201) }

        for position in 1 ... 3 {
            await outbox.enqueue(
                .createSetLog(
                    localID: LocalID(), log: .server(900), position: position, weightKg: 70, reps: 8
                )
            )
        }
        await outbox.drain()

        let positions = transport.requests.compactMap { request -> Int? in
            guard let body = request.bodyData(),
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let setLog = json["set_log"] as? [String: Any]
            else { return nil }
            return setLog["position"] as? Int
        }
        #expect(positions == [1, 2, 3], "sets must reach the server in the order they were performed")
    }

    @Test func reportsProgressToObservers() async {
        let (outbox, _) = makeOutbox { _ in .json(exerciseLogBody, status: 201) }
        let recorder = ProgressRecorder()

        let token = await outbox.observe { progress in recorder.record(progress) }
        await outbox.enqueue(.createExerciseLog(localID: LocalID(), sessionID: 2, workoutExerciseID: 10))
        await outbox.drain()
        await outbox.removeObserver(token)

        #expect(recorder.sawPending, "the UI needs to know something is in flight")
        #expect(recorder.latest?.isSettled == true)
    }
}

/// Collects observer callbacks, which arrive from the actor's context.
private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Outbox.Progress] = []

    func record(_ progress: Outbox.Progress) {
        lock.withLock { values.append(progress) }
    }

    var sawPending: Bool {
        lock.withLock { values.contains { $0.pending > 0 } }
    }

    var latest: Outbox.Progress? {
        lock.withLock { values.last }
    }
}

private extension URLRequest {
    /// URLSession replaces `httpBody` with a stream for some requests, so read
    /// whichever is populated.
    func bodyData() -> Data? {
        if let body = httpBody {
            return body
        }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: size)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
