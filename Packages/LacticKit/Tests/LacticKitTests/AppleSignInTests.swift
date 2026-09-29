import AuthenticationServices
import Foundation
import LacticCore
import Testing
@testable import LacticKit

@Suite("Sign in with Apple credential")
struct AppleSignInCredentialTests {
    @Test func readsTheTokenCodeAndFirstAuthorizationName() throws {
        var name = PersonNameComponents()
        name.givenName = "Alice"
        name.familyName = "Client"

        let credential = try AppleSignInProvider.credential(
            identityToken: Data("header.payload.signature".utf8),
            authorizationCode: Data("code-1".utf8),
            fullName: name
        )

        #expect(credential.identityToken == "header.payload.signature")
        #expect(credential.authorizationCode == "code-1")
        #expect(credential.fullName == "Alice Client")
    }

    /// Every sign-in after the first delivers empty components, not `nil`.
    /// Forwarding an empty string would give the API nothing to use and make
    /// the first-authorization name impossible to tell apart from no name.
    @Test func dropsTheEmptyNameOfEveryLaterSignIn() throws {
        let credential = try AppleSignInProvider.credential(
            identityToken: Data("token".utf8),
            authorizationCode: nil,
            fullName: PersonNameComponents()
        )
        #expect(credential.fullName == nil)
        #expect(credential.authorizationCode == nil)
    }

    @Test func refusesACredentialWithNoIdentityToken() {
        #expect(throws: AppleSignInProvider.Failure.missingIdentityToken) {
            try AppleSignInProvider.credential(identityToken: nil, authorizationCode: nil, fullName: nil)
        }
        #expect(throws: AppleSignInProvider.Failure.missingIdentityToken) {
            try AppleSignInProvider.credential(identityToken: Data(), authorizationCode: nil, fullName: nil)
        }
    }

    @Test func turnsBackingOutIntoCancelled() {
        let error = NSError(domain: ASAuthorizationError.errorDomain, code: ASAuthorizationError.canceled.rawValue)
        #expect(throws: AppleSignInProvider.Failure.cancelled) {
            try AppleSignInProvider.credential(from: .failure(error))
        }
    }

    /// Apple's own errors read "AuthorizationError error 1000", so they become
    /// a case the screen can phrase rather than text it would show verbatim.
    @Test func collapsesApplesOtherErrorsIntoFailed() {
        let error = NSError(domain: ASAuthorizationError.errorDomain, code: ASAuthorizationError.unknown.rawValue)
        #expect(throws: AppleSignInProvider.Failure.failed) {
            try AppleSignInProvider.credential(from: .failure(error))
        }
        #expect(InvitationFailure(AppleSignInProvider.Failure.failed) == .appleSignInFailed)
        #expect(InvitationFailure(SessionStore.WrongAppError(role: .coach)) == .coachAccount)
    }

    @Test func passesUnrelatedErrorsThrough() {
        let error = URLError(.notConnectedToInternet)
        #expect(throws: URLError.self) {
            try AppleSignInProvider.credential(from: .failure(error))
        }
    }
}

/// Free constants rather than members, like `SessionStoreTests`: the stub's
/// handler runs on whatever thread URLSession picks.
private let coachMeBody = #"{"id":9,"avatar_url":null,"email":"coach@example.com","name":"Jo Coach","role":"coach"}"#
private let coachAuthBody = """
{"access_token":"access-1","refresh_token":"refresh-1",\
"user":{"id":9,"name":"Jo Coach","email":"coach@example.com","role":"coach"}}
"""

@MainActor
@Suite("Sign in with Apple session", .serialized)
struct AppleSignInSessionTests {
    private func makeStore() -> (SessionStore, StubTransport) {
        let transport = StubTransport { request in
            request.url?.path.hasSuffix("/me") == true ? .json(coachMeBody) : .json(coachAuthBody)
        }
        let client = APIClient(
            configuration: APIConfiguration(baseURL: URL(string: "https://api.test")!) { "en" },
            session: transport.session
        )
        return (SessionStore(client: client, keychain: InMemoryStorage()), transport)
    }

    @Test func postsTheAppleTokenNameAndCodeToAuth() async throws {
        let (store, transport) = makeStore()
        let credential = AppleSignInProvider.Credential(
            identityToken: "id-token", authorizationCode: "code-1", fullName: "Jo Coach"
        )

        try await store.signInWithApple(credential, invitationToken: "invite-1")

        let request = try #require(transport.requests.first { $0.url?.path.hasSuffix("/auth") == true })
        let data = try #require(request.bodyData())
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(body == [
            "provider": "apple",
            "id_token": "id-token",
            "authorization_code": "code-1",
            "name": "Jo Coach",
            "invitation_token": "invite-1",
        ])
        #expect(store.phase.user?.email == "coach@example.com")
    }
}
