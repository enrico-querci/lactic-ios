import Foundation
import LacticCore
import Testing
@testable import LacticKit

private let invitationBody = """
{"id":7,"email":"alice@example.com","status":"pending","expires_at":"2026-12-01T00:00:00.000Z",\
"sent_at":null,"created_at":"2026-09-01T00:00:00.000Z","coach_name":"John Coach"}
"""
private let revokedInvitationBody = invitationBody.replacingOccurrences(
    of: #""status":"pending""#, with: #""status":"revoked""#
)
private let devLoginBody = """
{"access_token":"access-1","refresh_token":"refresh-1",\
"user":{"id":4,"name":"Alice","email":"alice@example.com","role":"client"}}
"""
private let unlinkedClientBody =
    #"{"id":4,"avatar_url":null,"email":"alice@example.com","name":"Alice","role":"client"}"#

@MainActor
@Suite("Invitation model", .serialized)
struct InvitationModelTests {
    private struct Harness {
        let model: InvitationModel
        let session: SessionStore
        let transport: StubTransport
    }

    private func make(
        handler: @escaping @Sendable (URLRequest) -> StubTransport.Response
    ) -> Harness {
        let transport = StubTransport(handler: handler)
        let client = APIClient(
            configuration: APIConfiguration(baseURL: URL(string: "https://api.test")!) { "en" },
            session: transport.session
        )
        let session = SessionStore(client: client, keychain: InMemoryStorage())
        Task { await client.setTokenProvider(session) }
        return Harness(
            model: InvitationModel(token: "tok-1", client: client, session: session),
            session: session,
            transport: transport
        )
    }

    @Test func loadsTheInvitationAndAsksASignedOutClientToSignIn() async {
        let harness = make { _ in .json(invitationBody) }
        let (model, session) = (harness.model, harness.session)
        await session.restore() // no stored token, so: signed out
        await model.load()

        #expect(model.invitation?.coachName == "John Coach")
        #expect(model.step == .signInRequired)
        #expect(model.failure == nil)
    }

    /// The common failure here is a mistyped code or a truncated link, so it
    /// must not read as though the app broke.
    @Test func aMissingInvitationSaysSoRatherThanFailing() async {
        let harness = make { _ in .json(#"{"error":"Not Found"}"#, status: 404) }
        let (model, session) = (harness.model, harness.session)
        await session.restore()
        await model.load()

        #expect(model.invitation == nil)
        #expect(model.step == nil)
        #expect(model.failure == .notFound)
    }

    @Test func theInvitedClientIsOfferedAcceptAndTheSessionAdoptsTheLinkedUser() async throws {
        let linked = #"{"id":4,"avatar_url":null,"email":"alice@example.com","name":"Alice","role":"client"}"#
        let harness = make { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/accept") {
                return .json(linked)
            }
            if path.contains("/client_invitations") {
                return .json(invitationBody)
            }
            if path.contains("dev_login") {
                return .json(devLoginBody)
            }
            return .json(unlinkedClientBody)
        }
        let (model, session) = (harness.model, harness.session)
        try await session.signInWithDevLogin(email: "alice@example.com")
        await model.load()
        #expect(model.step == .readyToAccept)

        let accepted = await model.accept()

        #expect(accepted)
        #expect(session.phase == .signedIn(
            User(id: 4, name: "Alice", email: "alice@example.com", role: .client, avatarURL: nil)
        ))
        #expect(harness.transport.requests.contains { $0.url?.path.hasSuffix("/accept") == true })
    }

    /// The server re-checks everything and knows what the client cannot — that
    /// the account already belongs to another coach, say. Its message wins, and
    /// the invitation is re-read in case it moved underneath us.
    @Test func aRejectedAcceptSurfacesTheServerMessageAndRefreshesTheInvitation() async throws {
        let attempts = Counter()
        let harness = make { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/accept") {
                return .json(#"{"error":"This account already belongs to another coach"}"#, status: 422)
            }
            if path.contains("/client_invitations") {
                return .json(attempts.next() == 0 ? invitationBody : revokedInvitationBody)
            }
            if path.contains("dev_login") {
                return .json(devLoginBody)
            }
            return .json(unlinkedClientBody)
        }
        let (model, session) = (harness.model, harness.session)
        try await session.signInWithDevLogin(email: "alice@example.com")
        await model.load()

        let accepted = await model.accept()

        #expect(!accepted)
        #expect(model.failure == .server("This account already belongs to another coach"))
        // Re-read, so the screen stops offering an action that cannot succeed.
        #expect(model.step == .unavailable(.revoked))
    }

    @Test func aCoachIsBlockedRatherThanOfferedAnAcceptThatWould422() async throws {
        let coachAuth = devLoginBody.replacingOccurrences(of: #""role":"client""#, with: #""role":"coach""#)
        let coachMe = unlinkedClientBody.replacingOccurrences(of: #""role":"client""#, with: #""role":"coach""#)
        let harness = make { request in
            let path = request.url?.path ?? ""
            if path.contains("/client_invitations") {
                return .json(invitationBody)
            }
            if path.contains("dev_login") {
                return .json(coachAuth)
            }
            return .json(coachMe)
        }
        let (model, session) = (harness.model, harness.session)
        try await session.signInWithDevLogin(email: "alice@example.com")
        await model.load()

        #expect(model.step == .blocked(
            .coachAccount, signedInAs: "alice@example.com", invited: "alice@example.com"
        ))
    }
}

/// A thread-safe call counter: the stub's handler runs off the main actor.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func next() -> Int {
        lock.withLock { defer { count += 1 }; return count }
    }
}
