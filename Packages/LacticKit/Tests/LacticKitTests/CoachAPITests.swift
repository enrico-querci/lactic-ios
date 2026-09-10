import Foundation
import LacticCore
import Testing
@testable import LacticKit

private func body(_ endpoint: Endpoint) throws -> [String: Any] {
    let data = try #require(endpoint.body)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

@Suite("Coach request encoding")
struct CoachRequestTests {
    /// Most coach writes are wrapped in a Rails root key, and getting the key
    /// wrong is a silent 400 rather than a compile error.
    @Test func writesAreWrappedInTheirRailsRootKey() throws {
        let program = try CoachAPI.createProgram(name: "Block 1", description: "Base")
        let wrapped = try #require(try body(program)["program"] as? [String: Any])
        #expect(wrapped["name"] as? String == "Block 1")
        #expect(wrapped["description"] as? String == "Base")
        #expect(program.method == .post)
        #expect(program.path == "/coach/programs")
    }

    /// Invitations and templates are the exceptions: their controllers read
    /// top-level params, so wrapping them would break the call.
    @Test func invitationsAndTemplatesAreNotWrapped() throws {
        let invite = try CoachAPI.createInvitation(email: "someone@example.com")
        #expect(try body(invite)["email"] as? String == "someone@example.com")

        let template = try CoachAPI.createWorkoutTemplate(name: "Push A", sourceWorkoutID: 6)
        let fields = try body(template)
        #expect(fields["name"] as? String == "Push A")
        #expect(fields["source_workout_id"] as? Int == 6)

        let apply = try CoachAPI.applyWorkoutTemplate(id: 1, targetWeekID: 4)
        #expect(try body(apply)["target_week_id"] as? Int == 4)
    }

    /// A PATCH must send only what it means to change: an explicit null would
    /// clear a column the caller never mentioned.
    @Test func aPatchOmitsTheFieldsItWasNotGiven() throws {
        let endpoint = try CoachAPI.updateWorkoutExercise(
            workoutID: 3, id: 9, changes: .init(reps: 10)
        )
        let fields = try #require(try body(endpoint)["workout_exercise"] as? [String: Any])
        #expect(fields["reps"] as? Int == 10)
        #expect(fields.count == 1, "sent \(fields.keys.sorted()) — a nil became an explicit null")
        #expect(endpoint.method == .patch)
    }

    @Test func aDecimalWeightSurvivesEncoding() throws {
        let endpoint = try CoachAPI.createWorkoutExercise(
            workoutID: 3,
            plan: .init(
                exerciseID: 12, position: "A", sets: 3, reps: 8,
                restSeconds: 90, rir: 2, weight: Decimal(string: "72.5")
            )
        )
        let fields = try #require(try body(endpoint)["workout_exercise"] as? [String: Any])
        #expect("\(fields["weight"] ?? "")" == "72.5")
        #expect(fields["notes"] == nil, "an omitted note must not be sent as null")
    }

    /// `start_date` is a plain calendar day, and must not acquire a time or a
    /// timezone on the way out.
    @Test func anAssignmentSendsADateWithoutATime() throws {
        let endpoint = try CoachAPI.createProgramAssignment(
            programID: 3, clientID: 7, startDate: CalendarDate(year: 2026, month: 9, day: 3), notes: nil
        )
        let fields = try #require(try body(endpoint)["program_assignment"] as? [String: Any])
        #expect(fields["start_date"] as? String == "2026-09-03")
    }

    @Test func onlyTheFiltersGivenBecomeQueryItems() {
        let endpoint = CoachAPI.exercises(search: "squat", custom: true, page: 2)
        let names = endpoint.query.map(\.name).sorted()
        #expect(names == ["custom", "page", "search"])
        #expect(endpoint.query.first { $0.name == "custom" }?.value == "true")
    }

    @Test func nestedPathsAddressTheRightResource() {
        #expect(CoachAPI.workouts(programID: 3, weekID: 4).path == "/coach/programs/3/weeks/4/workouts")
        #expect(CoachAPI.duplicateWorkout(programID: 3, weekID: 4, id: 6).path
            == "/coach/programs/3/weeks/4/workouts/6/duplicate")
        #expect(CoachAPI.clientProgress(clientID: 7).path == "/coach/clients/7/progress")
        #expect(CoachAPI.resendInvitation(id: 2).method == .post)
        #expect(CoachAPI.revokeInvitation(id: 2).method == .delete)
    }
}

@Suite("Coach response decoding")
struct CoachDecodingTests {
    @Test func decodesTheSubscription() throws {
        let sub = try Fixture.decode(CoachSubscription.self, from: "coach_subscription")
        #expect(sub.plan == .free)
        #expect(sub.clientLimit == 3)
        #expect(sub.clientSlotsUsed == 2)
        #expect(sub.expiresAt == nil)
        #expect(sub.billingIssue == false)
        #expect(sub.canInviteClient)
    }

    /// A null limit is the unlimited tier or a comped email, not a missing
    /// value — it must not read as "no clients allowed".
    @Test func aNullLimitMeansUnlimited() throws {
        let json = #"""
        {"plan":"unlimited","client_limit":null,"client_slots_used":40,
         "expires_at":null,"auto_renew":null,"billing_issue":false}
        """#
        let sub = try JSONCoding.decoder.decode(CoachSubscription.self, from: Data(json.utf8))
        #expect(sub.clientLimit == nil)
        #expect(sub.canInviteClient)
    }

    /// A tier added server-side must not make the whole payload undecodable —
    /// that would lock a paying coach out of their own billing screen.
    @Test func anUnknownPlanDecodesRatherThanThrowing() throws {
        let json = #"""
        {"plan":"team_annual","client_limit":50,"client_slots_used":1,
         "expires_at":null,"auto_renew":true,"billing_issue":false}
        """#
        let sub = try JSONCoding.decoder.decode(CoachSubscription.self, from: Data(json.utf8))
        #expect(sub.plan == .other("team_annual"))
        #expect(sub.plan.rawValue == "team_annual")
    }

    @Test func decodesClientsAndAssignments() throws {
        let clients = try Fixture.decode([User].self, from: "coach_clients")
        #expect(clients.count == 2)
        #expect(clients.allSatisfy { $0.role == .client })

        let assignments = try Fixture.decode([ProgramAssignment].self, from: "coach_program_assignments")
        let first = try #require(assignments.first)
        #expect(first.client.email == "alice@example.com")
        #expect(first.program.name == "Upper/Lower Split (dev)")
        #expect(first.startDate == CalendarDate(year: 2026, month: 9, day: 3))
        #expect(first.status == .active)
    }

    @Test func decodesAWorkoutTemplate() throws {
        let template = try Fixture.decode(WorkoutTemplate.self, from: "coach_workout_template")
        #expect(template.name == "Fixture template")
        #expect(template.sourceWorkoutID == 6)
    }

    /// The one billing state Studio must handle: a full plan blocks new
    /// invitations with a machine-readable code, captured verbatim from a real
    /// 402 rather than assumed.
    @Test func aFullPlanSurfacesAsClientLimitReached() throws {
        let payload = #"{"error":"You've reached your plan's client limit","code":"client_limit_reached"}"#
        let envelope = try JSONCoding.decoder.decode(APIErrorEnvelope.self, from: Data(payload.utf8))
        let error = APIError.api(
            status: 402,
            messages: envelope.messages,
            code: envelope.code,
            path: "/coach/client_invitations"
        )
        #expect(error.status == 402)
        #expect(error.code == "client_limit_reached")
        #expect(error.message == "You've reached your plan's client limit")
        #expect(!error.isRetryable, "retrying a full plan just fails again")
    }
}
