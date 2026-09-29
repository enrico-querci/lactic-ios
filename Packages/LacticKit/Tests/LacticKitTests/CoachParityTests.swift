import Foundation
import LacticCore
import Testing
@testable import LacticKit

// MARK: - Helpers

private func jsonBody(_ endpoint: Endpoint) throws -> [String: Any] {
    let data = try #require(endpoint.body)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func jsonBody(_ request: URLRequest) throws -> [String: Any] {
    let data = try #require(request.bodyData())
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

@MainActor
private func makeClient(
    _ handler: @escaping @Sendable (URLRequest) -> StubTransport.Response
) -> (APIClient, StubTransport) {
    let transport = StubTransport(handler: handler)
    let client = APIClient(
        configuration: APIConfiguration(baseURL: URL(string: "https://api.test")!) { "en" },
        session: transport.session
    )
    return (client, transport)
}

private func fixture(_ name: String) -> String {
    guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
          let text = try? String(contentsOf: url, encoding: .utf8)
    else { return "{}" }
    return text
}

private func workoutJSON(id: Int, name: String, day: Int) -> String {
    #"{"id":\#(id),"name":"\#(name)","day":\#(day),"volume_sets":{}}"#
}

private func workoutExerciseJSON(id: Int, position: String) -> String {
    """
    {"id":\(id),"position":"\(position)","sets":3,"reps":10,"rest_seconds":90,"rir":null,\
    "weight":null,"notes":null,"exercise":\(exerciseJSON(id: 50 + id))}
    """
}

private func exerciseJSON(id: Int, custom: Bool = false) -> String {
    """
    {"id":\(id),"name":"Exercise \(id)","is_custom":\(custom),"category":"strength",\
    "difficulty":"beginner","mechanic":null,"force":null,"prescription_type":"reps",\
    "active":true,"assignable":true,"primary_muscle":null,"equipment":[],\
    "has_animation":false,"animation_url":null,"muscle_group":"Chest",\
    "video_url":null,"thumbnail_url":null}
    """
}

private func assignmentJSON(id: Int, status: String, clientID: Int = 7, start: String = "2026-09-01") -> String {
    """
    {"id":\(id),"start_date":"\(start)","status":"\(status)","notes":null,\
    "program":{"id":3,"name":"Block","description":null,"created_at":"2026-09-01T00:00:00.000Z"},\
    "client":{"id":\(clientID),"name":"Alice","email":"alice@example.com","role":"client","avatar_url":null}}
    """
}

// MARK: - Request shapes

@Suite("Coach parity request shapes")
struct CoachParityRequestTests {
    /// The duplicate controller reads `target_week_id` and `day` at the top
    /// level. Wrapped, as the web sends them, they are silently ignored.
    @Test func duplicateSendsItsPlacementAtTheTopLevel() throws {
        let endpoint = try CoachAPI.duplicateWorkout(programID: 3, weekID: 4, id: 6, targetWeekID: 5, day: 2)
        let fields = try jsonBody(endpoint)
        #expect(fields["target_week_id"] as? Int == 5)
        #expect(fields["day"] as? Int == 2)
        #expect(fields["workout"] == nil)
    }

    /// Clearing an RIR, a weight or a note means sending null, which the
    /// partial PATCH deliberately never does.
    @Test func replacingAPrescriptionSendsExplicitNulls() throws {
        let endpoint = try CoachAPI.replaceWorkoutExercise(
            workoutID: 3, id: 9,
            plan: .init(exerciseID: 12, position: "B", sets: 4, reps: 6, restSeconds: 120)
        )
        let fields = try #require(try jsonBody(endpoint)["workout_exercise"] as? [String: Any])
        #expect(fields["sets"] as? Int == 4)
        #expect(fields["position"] as? String == "B")
        #expect(fields["rir"] is NSNull)
        #expect(fields["weight"] is NSNull)
        #expect(fields["notes"] is NSNull)
        #expect(endpoint.method == .patch)
    }

    @Test func assignmentFiltersBecomeQueryItems() {
        #expect(CoachAPI.programAssignments().query.isEmpty)
        let filtered = CoachAPI.programAssignments(clientID: 7, status: .paused)
        #expect(filtered.query.map(\.name).sorted() == ["client_id", "status"])
        #expect(filtered.query.first { $0.name == "status" }?.value == "paused")
    }

    @Test func aPickedDateBecomesItsCalendarDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Rome"))
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 23)))
        #expect(CalendarDate(date, calendar: calendar).description == "2026-03-29")
    }
}

// MARK: - Decoding

@Suite("Coach parity decoding")
struct CoachParityDecodingTests {
    /// The coach's programme has no `assignment_id`, which is exactly what
    /// makes the client's `ProgramDetail` unusable here.
    @Test func decodesTheCoachsProgramme() throws {
        let program = try Fixture.decode(CoachProgram.self, from: "coach_program_detail")
        #expect(program.name == "Upper/Lower Split (dev)")
        #expect(program.orderedWeeks.map(\.position) == [1, 2])
        #expect(program.weeks.allSatisfy { !$0.workouts.isEmpty })
        #expect(throws: DecodingError.self) {
            try Fixture.decode(ProgramDetail.self, from: "coach_program_detail")
        }
    }

    /// A created week carries no `workouts` key at all.
    @Test func decodesACreatedWeek() throws {
        let week = try Fixture.decode(WeekSummary.self, from: "coach_week_created")
        #expect(week.position == 9)
        #expect(throws: DecodingError.self) {
            try Fixture.decode(Week.self, from: "coach_week_created")
        }
    }
}

// MARK: - Programme builder

@MainActor
@Suite("Programme builder", .serialized)
struct ProgramBuilderModelTests {
    private let programBody = fixture("coach_program_detail")

    /// Positions are unique per programme, so the next week goes one past the
    /// highest — after deleting week 1 of 2, "count + 1" would collide.
    @Test func aNewWeekGoesOnePastTheHighestPosition() async throws {
        let programBody = programBody
        let (client, transport) = makeClient { request in
            request.httpMethod == "POST" ? .json(#"{"id":40,"position":3}"#, status: 201) : .json(programBody)
        }
        let model = ProgramBuilderModel(client: client, programID: 3)
        await model.load()

        #expect(await model.addWeek())

        let post = try #require(transport.requests.first { $0.httpMethod == "POST" })
        let fields = try #require(try jsonBody(post)["week"] as? [String: Any])
        #expect(fields["position"] as? Int == 3)
        #expect(model.orderedWeeks.last?.id == 40)
        #expect(model.orderedWeeks.last?.workouts.isEmpty == true)
    }

    @Test func aDuplicateLandsInTheWeekAndOnTheDayChosen() async throws {
        let programBody = programBody
        let (client, _) = makeClient { request in
            request.httpMethod == "POST"
                ? .json(workoutJSON(id: 99, name: "Upper A", day: 6), status: 201)
                : .json(programBody)
        }
        let model = ProgramBuilderModel(client: client, programID: 3)
        await model.load()
        let weeks = model.orderedWeeks
        let source = try #require(weeks.first?.workouts.first)
        let target = try #require(weeks.last)

        #expect(await model.duplicateWorkout(weekID: weeks[0].id, id: source.id, toWeek: target.id, day: 6))

        #expect(model.workouts(inWeek: target.id, day: 6).map(\.id) == [99])
    }

    @Test func renamingAWorkoutReplacesItInPlace() async throws {
        let programBody = programBody
        let fixtureProgram = try Fixture.decode(CoachProgram.self, from: "coach_program_detail")
        let week = try #require(fixtureProgram.orderedWeeks.first)
        let workout = try #require(week.workouts.first)
        let renamed = workoutJSON(id: workout.id, name: "Heavy upper", day: 2)
        let (client, _) = makeClient { request in
            request.httpMethod == "PATCH" ? .json(renamed) : .json(programBody)
        }
        let model = ProgramBuilderModel(client: client, programID: 3)
        await model.load()

        #expect(await model.updateWorkout(weekID: week.id, id: workout.id, name: "Heavy upper", day: 2))

        #expect(model.workouts(inWeek: week.id, day: 2).contains { $0.name == "Heavy upper" })
        #expect(model.orderedWeeks.first?.workouts.count == week.workouts.count)
    }

    @Test func applyingATemplateSendsTheDay() async throws {
        let programBody = programBody
        let (client, transport) = makeClient { request in
            if request.url?.path.hasSuffix("/apply") == true {
                return .json(workoutJSON(id: 77, name: "Push", day: 3), status: 201)
            }
            if request.url?.path.hasSuffix("/workout_templates") == true {
                return .json("[]")
            }
            return .json(programBody)
        }
        let model = ProgramBuilderModel(client: client, programID: 3)
        await model.load()
        let week = try #require(model.orderedWeeks.first)

        #expect(await model.applyTemplate(id: 2, toWeek: week.id, day: 3))

        let apply = try #require(transport.requests.first { $0.url?.path.hasSuffix("/apply") == true })
        #expect(try jsonBody(apply)["day"] as? Int == 3)
        #expect(model.workouts(inWeek: week.id, day: 3).contains { $0.id == 77 })
    }

    @Test func aFailedChangeLeavesTheProgrammeAsItWas() async {
        let programBody = programBody
        let (client, _) = makeClient { request in
            request.httpMethod == "DELETE"
                ? .json(#"{"error":"Not found"}"#, status: 404)
                : .json(programBody)
        }
        let model = ProgramBuilderModel(client: client, programID: 3)
        await model.load()
        let before = model.program

        #expect(await model.deleteWeek(id: 4) == false)

        #expect(model.program == before)
        #expect(model.failure == .rejected("Not found"))
    }
}

// MARK: - Workout editor

@MainActor
@Suite("Workout editor", .serialized)
struct WorkoutEditorModelTests {
    @Test func theNextLetterIsTheFirstFreeOne() {
        #expect(WorkoutEditorModel.nextFreePosition(after: []) == "A")
        #expect(WorkoutEditorModel.nextFreePosition(after: ["A", "C"]) == "B")
        let all = (65 ... 90).compactMap { UnicodeScalar($0).map { String(Character($0)) } }
        #expect(WorkoutEditorModel.nextFreePosition(after: all) == nil)
    }

    @Test func anAddedExerciseTakesTheFreeLetterAndTheDefaults() async throws {
        let workout = """
        {"id":8,"name":"Upper A","day":1,"volume_sets":{},"workout_exercises":[\
        \(workoutExerciseJSON(id: 1, position: "A")),\(workoutExerciseJSON(id: 3, position: "C"))]}
        """
        let (client, transport) = makeClient { request in
            request.httpMethod == "POST"
                ? .json(workoutExerciseJSON(id: 4, position: "B"), status: 201)
                : .json(workout)
        }
        let model = WorkoutEditorModel(client: client, programID: 3, weekID: 4, workoutID: 8)
        await model.load()
        let exercise = try JSONCoding.decoder.decode(Exercise.self, from: Data(exerciseJSON(id: 60).utf8))

        #expect(await model.addExercise(exercise))

        let post = try #require(transport.requests.first { $0.httpMethod == "POST" })
        let fields = try #require(try jsonBody(post)["workout_exercise"] as? [String: Any])
        #expect(fields["position"] as? String == "B")
        #expect(fields["sets"] as? Int == 3)
        #expect(fields["reps"] as? Int == 10)
        #expect(fields["rest_seconds"] as? Int == 90)
    }

    /// Editing keeps the exercise and its letter and replaces everything else.
    @Test func anEditReplacesThePrescriptionAndKeepsTheLetter() async throws {
        let workout = """
        {"id":8,"name":"Upper A","day":1,"volume_sets":{},"workout_exercises":[\
        \(workoutExerciseJSON(id: 1, position: "A"))]}
        """
        let (client, transport) = makeClient { request in
            request.httpMethod == "PATCH" ? .json(workoutExerciseJSON(id: 1, position: "A")) : .json(workout)
        }
        let model = WorkoutEditorModel(client: client, programID: 3, weekID: 4, workoutID: 8)
        await model.load()

        #expect(await model.updateExercise(
            id: 1, to: .init(sets: 5, reps: 5, restSeconds: 180, notes: "  ")
        ))

        let patch = try #require(transport.requests.first { $0.httpMethod == "PATCH" })
        let fields = try #require(try jsonBody(patch)["workout_exercise"] as? [String: Any])
        #expect(fields["position"] as? String == "A")
        #expect(fields["exercise_id"] as? Int == 51)
        #expect(fields["sets"] as? Int == 5)
        #expect(fields["notes"] is NSNull, "a blank note is cleared, not stored")
    }
}

// MARK: - Catalog

@MainActor
@Suite("Exercise catalog", .serialized)
struct ExerciseCatalogModelTests {
    private func page(_ ids: [Int], page: Int, totalPages: Int) -> StubTransport.Response {
        let body = "[" + ids.map { exerciseJSON(id: $0) }.joined(separator: ",") + "]"
        return StubTransport.Response(
            status: 200, body: Data(body.utf8),
            headers: [
                "X-Total-Count": "\(totalPages * 2)", "X-Page": "\(page)",
                "X-Per-Page": "2", "X-Total-Pages": "\(totalPages)",
            ]
        )
    }

    @Test func theFilterBecomesQueryItemsAndMoreIsAppended() async throws {
        let first = page([1, 2], page: 1, totalPages: 2)
        let second = page([2, 3], page: 2, totalPages: 2)
        let (client, transport) = makeClient { request in
            if request.url?.path.hasSuffix("/exercise_taxonomy") == true {
                return .json(#"{"muscles":[],"equipment":[],"categories":[],"difficulties":[]}"#)
            }
            let pageNumber = request.url
                .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
                .queryItems?.first { $0.name == "page" }?.value
            return pageNumber == "2" ? second : first
        }
        let model = ExerciseCatalogModel(client: client, perPage: 2)
        model.filter.search = "  squat "
        model.filter.ownership = .mine
        await model.load()
        await model.loadMore()

        #expect(model.exercises.map(\.id) == [1, 2, 3], "a row repeated across pages is shown once")
        #expect(model.hasMore == false)
        let list = try #require(transport.requests.first { $0.url?.path.hasSuffix("/coach/exercises") == true })
        let query = try URLComponents(url: #require(list.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(query.first { $0.name == "search" }?.value == "squat")
        #expect(query.first { $0.name == "custom" }?.value == "true")
    }
}

// MARK: - Assignments

@MainActor
@Suite("Assignments", .serialized)
struct AssignmentModelTests {
    /// Pausing an assignment while the list shows only active ones takes it
    /// off the list, the same as a fresh load would.
    @Test func aStatusChangeLeavesAFilteredList() async {
        let (client, _) = makeClient { request in
            request.httpMethod == "PATCH"
                ? .json(assignmentJSON(id: 1, status: "paused"))
                : .json("[\(assignmentJSON(id: 1, status: "active")),\(assignmentJSON(id: 2, status: "active"))]")
        }
        let model = AssignmentListModel(client: client)
        model.statusFilter = .active
        await model.load()

        #expect(await model.setStatus(.paused, forAssignment: 1))

        #expect(model.assignments.map(\.id) == [2])
    }

    @Test func aNewAssignmentJoinsOnlyTheListItBelongsTo() throws {
        let (client, _) = makeClient { _ in .json("[]") }
        let forAlice = AssignmentListModel(client: client, clientID: 7)
        let forBob = AssignmentListModel(client: client, clientID: 8)
        let assignment = try JSONCoding.decoder.decode(
            ProgramAssignment.self, from: Data(assignmentJSON(id: 5, status: "active", clientID: 7).utf8)
        )

        forAlice.didCreate(assignment)
        forBob.didCreate(assignment)

        #expect(forAlice.assignments.map(\.id) == [5])
        #expect(forBob.assignments.isEmpty)
    }

    @Test func creatingAnAssignmentSendsAPlainStartDate() async throws {
        let (client, transport) = makeClient { request in
            request.httpMethod == "POST"
                ? .json(assignmentJSON(id: 9, status: "active"), status: 201)
                : .json("[]")
        }
        let model = NewAssignmentModel(client: client)

        let created = await model.create(
            programID: 3, clientID: 7, startDate: CalendarDate(year: 2026, month: 10, day: 5), notes: " "
        )

        #expect(created?.id == 9)
        let post = try #require(transport.requests.first { $0.httpMethod == "POST" })
        let fields = try #require(try jsonBody(post)["program_assignment"] as? [String: Any])
        #expect(fields["start_date"] as? String == "2026-10-05")
        #expect(fields["notes"] == nil, "a blank note is not sent")
    }
}
