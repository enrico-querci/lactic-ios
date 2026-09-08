import Foundation
import LacticCore
import Testing
@testable import LacticKit

/// Rails' ParamsWrapper is switched off in this API, so every `params.require`
/// controller genuinely needs an explicit root key on the wire. Getting it
/// wrong is a 400 that reads like a client bug, so it is pinned here.
@Suite("Request encoding")
struct RequestEncodingTests {
    private func json(_ endpoint: Endpoint) throws -> [String: Any] {
        let body = try #require(endpoint.body)
        return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    @Test func wrapsASetLogInItsRootKey() throws {
        let endpoint = try ClientAPI.createSetLog(
            exerciseLogID: 4, position: 1, weightKg: #require(Decimal(string: "72.5")), reps: 8
        )
        let body = try json(endpoint)
        let payload = try #require(body["set_log"] as? [String: Any])
        #expect(payload["exercise_log_id"] as? Int == 4)
        #expect(payload["position"] as? Int == 1)
        #expect(payload["reps"] as? Int == 8)
        #expect(endpoint.method == .post)
        #expect(endpoint.path == "/client/set_logs")
    }

    /// Reads return `"72.5"`; writes must send a number, because the column is
    /// numeric and strong params feed it directly.
    @Test func sendsWeightAsANumberNotAString() throws {
        let endpoint = try ClientAPI.createSetLog(
            exerciseLogID: 4, position: 1, weightKg: #require(Decimal(string: "72.5")), reps: 8
        )
        let raw = try String(decoding: #require(endpoint.body), as: UTF8.self)
        #expect(raw.contains("72.5"))
        #expect(!raw.contains("\"72.5\""))
    }

    @Test func wrapsASessionAndSendsAnISO8601Timestamp() throws {
        let started = try #require(APIDateFormat.date(from: "2026-09-08T11:00:00.000Z"))
        let endpoint = try ClientAPI.startSession(
            workoutID: 3, programAssignmentID: 1, startedAt: started
        )
        let body = try json(endpoint)
        let payload = try #require(body["workout_session"] as? [String: Any])
        #expect(payload["workout_id"] as? Int == 3)
        #expect(payload["program_assignment_id"] as? Int == 1)
        #expect(payload["started_at"] as? String == "2026-09-08T11:00:00.000Z")
    }

    @Test func wrapsAnExerciseLogAndAlwaysCarriesItsSessionID() throws {
        let endpoint = try ClientAPI.createExerciseLog(workoutSessionID: 2, workoutExerciseID: 10)
        let body = try json(endpoint)
        let payload = try #require(body["exercise_log"] as? [String: Any])
        #expect(payload["workout_session_id"] as? Int == 2)
        #expect(payload["workout_exercise_id"] as? Int == 10)
    }

    @Test func wrapsAProfileUpdateInAUserKey() throws {
        let endpoint = try ClientAPI.updateProfile(name: "Alice", avatarURL: nil)
        let body = try json(endpoint)
        let payload = try #require(body["user"] as? [String: Any])
        #expect(payload["name"] as? String == "Alice")
        #expect(endpoint.method == .patch)
    }

    /// The auth routes are the exception: top-level params, no wrapper.
    @Test func sendsAuthBodiesWithoutAWrapper() throws {
        let loginBody = try json(ClientAPI.devLogin(email: "alice@example.com"))
        #expect(loginBody["email"] as? String == "alice@example.com")
        #expect(loginBody["user"] == nil)

        let refreshBody = try json(ClientAPI.refresh(refreshToken: "abc"))
        #expect(refreshBody["refresh_token"] as? String == "abc")
    }

    @Test func omitsTheInvitationTokenWhenThereIsNone() throws {
        let without = try json(ClientAPI.signIn(provider: "google", idToken: "tok", invitationToken: nil))
        #expect(without["invitation_token"] == nil)

        let with = try json(ClientAPI.signIn(provider: "google", idToken: "tok", invitationToken: "inv"))
        #expect(with["invitation_token"] as? String == "inv")
    }

    /// Auth endpoints must not carry a bearer token or trigger a refresh, and
    /// the public invitation lookup is deliberately unauthenticated.
    @Test func marksUnauthenticatedEndpoints() throws {
        let devLogin = try ClientAPI.devLogin(email: "a@b.c")
        let refresh = try ClientAPI.refresh(refreshToken: "x")
        #expect(devLogin.requiresAuthentication == false)
        #expect(refresh.requiresAuthentication == false)
        #expect(ClientAPI.invitation(token: "raw-token").requiresAuthentication == false)

        #expect(ClientAPI.acceptInvitation(token: "raw-token").requiresAuthentication)
        #expect(ClientAPI.me.requiresAuthentication)
    }

    @Test func percentEncodesAnInvitationTokenInThePath() {
        let endpoint = ClientAPI.invitation(token: "a/b+c")
        #expect(!endpoint.path.contains("a/b+c"))
        #expect(endpoint.path.hasPrefix("/client_invitations/"))
    }

    @Test func buildsPaginationQueryItems() {
        let endpoint = ClientAPI.exercises(search: "squat", page: 2, perPage: 20)
        let names = Dictionary(uniqueKeysWithValues: endpoint.query.map { ($0.name, $0.value) })
        #expect(names["page"] == "2")
        #expect(names["per_page"] == "20")
        #expect(names["search"] == "squat")
    }
}
