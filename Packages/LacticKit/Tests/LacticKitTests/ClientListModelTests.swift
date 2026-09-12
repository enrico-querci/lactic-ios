import Foundation
import LacticCore
import Testing
@testable import LacticKit

private let clientsBody = """
[{"id":7,"avatar_url":null,"email":"alice@example.com","name":"Alice Client","role":"client"},\
{"id":8,"avatar_url":null,"email":"bob@example.com","name":"Bob Client","role":"client"}]
"""
private func invitationBody(id: Int, email: String, status: String = "pending") -> String {
    """
    {"id":\(id),"email":"\(email)","status":"\(status)","expires_at":"2026-12-01T00:00:00.000Z",\
    "sent_at":null,"created_at":"2026-09-01T00:00:00.000Z","coach_name":"John Coach"}
    """
}

private func subscriptionBody(used: Int, limit: Int?) -> String {
    let limitValue = limit.map(String.init) ?? "null"
    return """
    {"plan":"free","client_limit":\(limitValue),"client_slots_used":\(used),\
    "expires_at":null,"auto_renew":null,"billing_issue":false}
    """
}

private let planFullBody = #"{"error":"You've reached your plan's client limit","code":"client_limit_reached"}"#

@MainActor
@Suite("Coach client list", .serialized)
struct ClientListModelTests {
    private func make(
        handler: @escaping @Sendable (URLRequest) -> StubTransport.Response
    ) -> (ClientListModel, StubTransport) {
        let transport = StubTransport(handler: handler)
        let client = APIClient(
            configuration: APIConfiguration(baseURL: URL(string: "https://api.test")!) { "en" },
            session: transport.session
        )
        return (ClientListModel(client: client), transport)
    }

    /// One screen, three reads. All must land before the roster means anything.
    @Test func loadsClientsInvitationsAndPlanTogether() async {
        let (model, _) = make { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/clients") {
                return .json(clientsBody)
            }
            if path.hasSuffix("/client_invitations") {
                return .json("[\(invitationBody(id: 3, email: "carol@example.com"))]")
            }
            return .json(subscriptionBody(used: 2, limit: 3))
        }
        await model.load()

        #expect(model.clients.count == 2)
        #expect(model.pendingInvitations.map(\.email) == ["carol@example.com"])
        #expect(model.subscription?.clientSlotsUsed == 2)
        #expect(model.canInviteClient)
        #expect(model.failure == nil)
    }

    /// Accepted and revoked invitations cannot be resent or revoked, so they
    /// must not reach the part of the screen that offers those actions.
    @Test func onlyPendingInvitationsAreOffered() async {
        let (model, _) = make { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/clients") {
                return .json("[]")
            }
            if path.hasSuffix("/client_invitations") {
                return .json("""
                [\(invitationBody(id: 1, email: "a@example.com")),\
                \(invitationBody(id: 2, email: "b@example.com", status: "accepted")),\
                \(invitationBody(id: 3, email: "c@example.com", status: "revoked"))]
                """)
            }
            return .json(subscriptionBody(used: 0, limit: 3))
        }
        await model.load()

        #expect(model.invitations.count == 3)
        #expect(model.pendingInvitations.map(\.id) == [1])
    }

    @Test func aNewInvitationJoinsTheListWithoutAReload() async {
        let slotsUsed = Counter(values: [0, 1])
        let (model, transport) = make { request in
            let path = request.url?.path ?? ""
            if request.httpMethod == "POST", path.hasSuffix("/client_invitations") {
                return .json(invitationBody(id: 9, email: "new@example.com"), status: 201)
            }
            if path.hasSuffix("/clients") {
                return .json("[]")
            }
            if path.hasSuffix("/client_invitations") {
                return .json("[]")
            }
            return .json(subscriptionBody(used: slotsUsed.next(), limit: 3))
        }
        await model.load()
        let invited = await model.invite(email: "new@example.com")

        #expect(invited)
        #expect(model.pendingInvitations.map(\.email) == ["new@example.com"])
        #expect(model.subscription?.clientSlotsUsed == 1)
        // The roster is merged rather than re-fetched; only one create is sent.
        let creates = transport.requests.filter {
            $0.httpMethod == "POST" && $0.url?.path.hasSuffix("/client_invitations") == true
        }
        #expect(creates.count == 1)
    }

    /// The one billing state Studio has to handle. The way out is upgrading,
    /// not correcting the input, so it is its own case rather than a message.
    @Test func aFullPlanIsItsOwnStateAndRefreshesTheUsage() async {
        let slotsUsed = Counter(values: [2, 3])
        let (model, _) = make { request in
            let path = request.url?.path ?? ""
            if request.httpMethod == "POST", path.hasSuffix("/client_invitations") {
                return .json(planFullBody, status: 402)
            }
            if path.hasSuffix("/clients") {
                return .json("[]")
            }
            if path.hasSuffix("/client_invitations") {
                return .json("[]")
            }
            // Under the limit on first read, full on the refresh: the plan
            // filled up between the coach opening the screen and inviting.
            return .json(subscriptionBody(used: slotsUsed.next(), limit: 3))
        }
        await model.load()
        #expect(model.canInviteClient, "the screen should have offered the invite")

        let invited = await model.invite(email: "fourth@example.com")

        #expect(!invited)
        #expect(model.failure == .planIsFull)
        #expect(model.pendingInvitations.isEmpty)
        // The usage shown must justify the refusal the coach just saw.
        #expect(model.subscription?.clientSlotsUsed == 3)
        #expect(!model.canInviteClient)
    }

    /// A rejection the coach can act on keeps the server's own wording, which
    /// is written per case and more useful than anything restated here.
    @Test func aRejectedAddressKeepsTheServersReason() async {
        let (model, _) = make { request in
            let path = request.url?.path ?? ""
            if request.httpMethod == "POST", path.hasSuffix("/client_invitations") {
                return .json(#"{"error":"This person already belongs to another coach"}"#, status: 409)
            }
            if path.hasSuffix("/clients") {
                return .json("[]")
            }
            if path.hasSuffix("/client_invitations") {
                return .json("[]")
            }
            return .json(subscriptionBody(used: 0, limit: 3))
        }
        await model.load()
        let invited = await model.invite(email: "taken@example.com")

        #expect(!invited)
        #expect(model.failure == .rejected("This person already belongs to another coach"))
    }

    @Test func resendingReplacesTheInvitationRatherThanDuplicatingIt() async {
        let (model, _) = make { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/resend") {
                return .json(invitationBody(id: 1, email: "a@example.com"))
            }
            if path.hasSuffix("/clients") {
                return .json("[]")
            }
            if path.hasSuffix("/client_invitations") {
                return .json("[\(invitationBody(id: 1, email: "a@example.com"))]")
            }
            return .json(subscriptionBody(used: 0, limit: 3))
        }
        await model.load()
        let resent = await model.resend(invitationID: 1)

        #expect(resent)
        #expect(model.invitations.count == 1)
    }

    /// Revoking returns a slot, so a plan that was full must stop reading as
    /// full without the coach reloading the screen.
    @Test func revokingFreesASlot() async {
        let slotsUsed = Counter(start: 3)
        let (model, _) = make { request in
            let path = request.url?.path ?? ""
            if request.httpMethod == "DELETE" {
                return .json("{}", status: 204)
            }
            if path.hasSuffix("/clients") {
                return .json("[]")
            }
            if path.hasSuffix("/client_invitations") {
                return .json("[\(invitationBody(id: 1, email: "a@example.com"))]")
            }
            return .json(subscriptionBody(used: slotsUsed.next(), limit: 3))
        }
        await model.load()
        #expect(!model.canInviteClient)

        let revoked = await model.revoke(invitationID: 1)

        #expect(revoked)
        #expect(model.pendingInvitations.isEmpty)
        #expect(model.canInviteClient, "the freed slot should be visible without a reload")
    }

    @Test func removingAClientDropsThemFromTheRoster() async {
        let (model, _) = make { request in
            let path = request.url?.path ?? ""
            if request.httpMethod == "DELETE" {
                return .json("{}", status: 204)
            }
            if path.hasSuffix("/clients") {
                return .json(clientsBody)
            }
            if path.hasSuffix("/client_invitations") {
                return .json("[]")
            }
            return .json(subscriptionBody(used: 2, limit: 3))
        }
        await model.load()
        let removed = await model.removeClient(id: 7)

        #expect(removed)
        #expect(model.clients.map(\.id) == [8])
    }

    /// Offline must not read as a refusal the coach could fix by editing, and
    /// a full plan must not read as a generic server error. Checked on the
    /// mapping itself: the stub can only answer with HTTP responses, so it
    /// cannot produce a real transport failure.
    @Test func failuresMapToTheReasonTheyNeed() {
        #expect(CoachActionFailure(APIError.transport(URLError(.notConnectedToInternet))) == .offline)
        #expect(CoachActionFailure(
            APIError.api(status: 402, messages: ["full"], code: "client_limit_reached", path: "/x")
        ) == .planIsFull)
        #expect(CoachActionFailure(
            APIError.api(status: 409, messages: ["Belongs to another coach"], code: nil, path: "/x")
        ) == .rejected("Belongs to another coach"))
    }

    @Test func aFailedLoadIsReported() async {
        let (model, _) = make { _ in .json(#"{"error":"Boom"}"#, status: 500) }
        await model.load()
        #expect(model.failure == .rejected("Boom"))
    }

    /// A fetch that failed must not hide the invite control: a 402 is a far
    /// better outcome than a coach who cannot invite and is not told why.
    @Test func anUnknownPlanStillOffersTheInviteControl() {
        let (model, _) = make { _ in .json("{}") }
        #expect(model.subscription == nil)
        #expect(model.canInviteClient)
    }
}

/// Walks a scripted sequence of values, holding the last one. Thread-safe
/// because the stub's handler runs off the main actor.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Int]
    private var index = 0

    init(values: [Int]) {
        self.values = values
    }

    convenience init(start: Int) {
        self.init(values: [start, max(0, start - 1)])
    }

    func next() -> Int {
        lock.withLock {
            let value = values[min(index, values.count - 1)]
            index += 1
            return value
        }
    }
}
