import Foundation
import LacticCore
import Testing
@testable import LacticKit

private func makeExercise(id: Int, reps: Int = 8, weight: Decimal? = 60) -> WorkoutExercise {
    let json = """
    {"id":\(id),"position":"A","sets":3,"reps":\(reps),"rest_seconds":90,"rir":2,
     "weight":\(weight.map { "\"\($0)\"" } ?? "null"),"notes":null,
     "exercise":{"id":1,"name":"Bench","is_custom":false,"category":null,"difficulty":null,
     "mechanic":null,"force":null,"prescription_type":"repetitions","active":true,
     "assignable":true,"primary_muscle":null,"equipment":[],"has_animation":false,
     "animation_url":null,"muscle_group":"Chest","video_url":null,"thumbnail_url":null}}
    """
    // swiftlint:disable:next force_try
    return try! JSONCoding.decoder.decode(WorkoutExercise.self, from: Data(json.utf8))
}

@MainActor
@Suite("Workout recorder")
struct WorkoutRecorderTests {
    /// A recorder wired to a scripted transport. A struct rather than a tuple
    /// so tests name what they need instead of destructuring three values.
    private struct Harness {
        let recorder: WorkoutRecorder
        let outbox: Outbox
        let transport: StubTransport
    }

    private func makeRecorder(
        store: any OutboxStoring = InMemoryOutboxStore(),
        handler: @escaping @Sendable (URLRequest) -> StubTransport.Response
    ) -> Harness {
        let transport = StubTransport(handler: handler)
        let client = APIClient(
            configuration: APIConfiguration(baseURL: URL(string: "https://api.test")!) { "en" },
            session: transport.session
        )
        let outbox = Outbox(client: client, store: store)
        return Harness(
            recorder: WorkoutRecorder(sessionID: 2, outbox: outbox),
            outbox: outbox,
            transport: transport
        )
    }

    /// The web's own bug, and the reason the rule exists: the API rejects
    /// `reps <= 0`, so a set added with empty values can never be created and
    /// "add set" simply does not work.
    @Test func addsASetPreFilledFromTheCoachesTargetNeverZeros() async {
        let harness = makeRecorder { _ in .json("{}", status: 503) }
        let recorder = harness.recorder
        let exercise = makeExercise(id: 10, reps: 8, weight: Decimal(string: "72.5"))

        let set = await recorder.addSet(to: exercise)

        #expect(set.reps == 8)
        #expect(set.weightKg == Decimal(string: "72.5"))
        #expect(set.position == 1)
    }

    /// An exercise with no suggested weight still has to produce a valid set.
    @Test func fallsBackToAValidSetWhenTheCoachSuggestedNothing() async {
        let harness = makeRecorder { _ in .json("{}", status: 503) }
        let recorder = harness.recorder
        let exercise = makeExercise(id: 10, reps: 0, weight: nil)

        let set = await recorder.addSet(to: exercise)

        #expect(set.weightKg == 0, "zero weight is valid; the API only requires reps > 0")
        #expect(set.reps >= 1, "reps must never be zero or the create is rejected")
    }

    /// The trainee sees the set immediately, before any network call resolves.
    @Test func showsASetBeforeTheServerHasAcceptedIt() async {
        let harness = makeRecorder { _ in .json("{}", status: 503) }
        let recorder = harness.recorder
        let exercise = makeExercise(id: 10)

        await recorder.addSet(to: exercise)

        #expect(recorder.entries[10]?.sets.count == 1)
        #expect(recorder.entries[10]?.sets.first?.serverID == nil, "not saved yet, but visible")
    }

    /// Positions increment per exercise, and extra sets beyond the coach's
    /// target are allowed — that is the "add set" feature, not an error.
    @Test func numbersSetsSequentiallyAndAllowsExtras() async {
        let harness = makeRecorder { _ in .json("{}", status: 503) }
        let recorder = harness.recorder
        let exercise = makeExercise(id: 10)

        for _ in 0 ..< 5 {
            await recorder.addSet(to: exercise)
        }

        #expect(recorder.entries[10]?.orderedSets.map(\.position) == [1, 2, 3, 4, 5])
    }

    /// The exercise log is created once, on the first set — not per set, and
    /// not up front for exercises the trainee skips.
    @Test func createsTheExerciseLogLazilyAndOnlyOnce() async {
        let harness = makeRecorder { request in
            request.url?.path.hasSuffix("/exercise_logs") == true
                ? .json(#"{"id":900,"notes":null,"photo_url":null,"workout_exercise_id":10}"#, status: 201)
                : .json(#"{"id":501,"position":1,"reps":8,"weight_kg":"60.0"}"#, status: 201)
        }
        let recorder = harness.recorder
        let exercise = makeExercise(id: 10)

        await recorder.addSet(to: exercise)
        await recorder.addSet(to: exercise)
        // Let the detached drain finish.
        try? await Task.sleep(for: .milliseconds(200))

        #expect(harness.transport.requestCount(forPathSuffix: "/exercise_logs") == 1)
    }

    /// A session resumed after the app was killed has to show what was already
    /// logged, addressed by server id so later edits hit the real rows.
    @Test func hydratesFromASessionTheServerAlreadyHas() throws {
        let harness = makeRecorder { _ in .json("{}") }
        let recorder = harness.recorder
        let json = """
        {"id":2,"completed_at":null,"notes":"felt good","started_at":"2026-09-08T11:00:00.000Z",
         "workout_id":3,"exercise_logs":[{"id":900,"notes":"tough","photo_url":null,
         "workout_exercise_id":10,"set_logs":[
           {"id":501,"position":1,"reps":8,"weight_kg":"60.0"},
           {"id":502,"position":2,"reps":6,"weight_kg":"62.5"}]}]}
        """
        let detail = try JSONCoding.decoder.decode(WorkoutSessionDetail.self, from: Data(json.utf8))

        recorder.hydrate(from: detail)

        #expect(recorder.notes == "felt good")
        #expect(recorder.entries[10]?.serverID == 900)
        #expect(recorder.entries[10]?.notes == "tough")
        #expect(recorder.entries[10]?.orderedSets.map(\.serverID) == [501, 502])
        #expect(recorder.entries[10]?.orderedSets.map(\.reps) == [8, 6])
    }

    /// Adding a set after resuming must continue the numbering rather than
    /// restart at 1 and collide with an existing position.
    @Test func continuesNumberingAfterResuming() async throws {
        let harness = makeRecorder { _ in .json("{}", status: 503) }
        let recorder = harness.recorder
        let json = """
        {"id":2,"completed_at":null,"notes":null,"started_at":"2026-09-08T11:00:00.000Z",
         "workout_id":3,"exercise_logs":[{"id":900,"notes":null,"photo_url":null,
         "workout_exercise_id":10,"set_logs":[{"id":501,"position":1,"reps":8,"weight_kg":"60.0"}]}]}
        """
        try recorder.hydrate(from: JSONCoding.decoder.decode(WorkoutSessionDetail.self, from: Data(json.utf8)))

        let added = await recorder.addSet(to: makeExercise(id: 10))

        #expect(added.position == 2, "position 1 is taken; reusing it would hit the unique index")
    }

    @Test func removesADeletedSetImmediately() async {
        let harness = makeRecorder { _ in .json("{}", status: 503) }
        let recorder = harness.recorder
        let exercise = makeExercise(id: 10)
        let first = await recorder.addSet(to: exercise)
        await recorder.addSet(to: exercise)

        await recorder.deleteSet(first.id, in: 10)

        #expect(recorder.entries[10]?.sets.count == 1)
        #expect(recorder.entries[10]?.sets.contains { $0.id == first.id } == false)
    }

    @Test func recordsNotesAndCompletion() async {
        let harness = makeRecorder { _ in .json("{}", status: 503) }
        let recorder = harness.recorder

        await recorder.setSessionNotes("hard session")
        await recorder.complete(at: Date(timeIntervalSince1970: 1_000_000))

        #expect(recorder.notes == "hard session")
        #expect(recorder.completedAt == Date(timeIntervalSince1970: 1_000_000))
    }

    /// Everything the trainee does must be durable before the network is
    /// involved, so a force-quit mid-workout loses nothing.
    @Test func queuesEveryActionDurably() async {
        let store = InMemoryOutboxStore()
        let harness = makeRecorder(store: store) { _ in .json("{}", status: 503) }
        let recorder = harness.recorder
        let exercise = makeExercise(id: 10)

        await recorder.addSet(to: exercise)
        await recorder.setNotes("felt heavy", for: exercise)

        let queued = try? store.load().operations
        #expect(queued?.isEmpty == false)
        // The exercise log create, the set create, and the notes update.
        #expect(queued?.count == 3)
    }
}
