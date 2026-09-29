import Foundation
import LacticCore
import Testing
@testable import LacticKit

/// Response bodies used by the stub. Free functions rather than members: the
/// stub's handler runs on whatever thread URLSession picks, so it cannot reach
/// anything isolated to the main actor.
private let meBody = #"{"id":4,"avatar_url":null,"email":"alice@example.com","name":"Alice Client","role":"client"}"#
private let authBody = """
{"access_token":"access-1","refresh_token":"refresh-1",\
"user":{"id":4,"name":"Alice Client","email":"alice@example.com","role":"client"}}
"""

private let aliceClient = User(
    id: 4, name: "Alice Client", email: "alice@example.com", role: .client, avatarURL: nil
)

@MainActor
@Suite("Session lifecycle", .serialized)
struct SessionStoreTests {
    private static let refreshKey = "refresh_token"

    private func makeStore(
        storage: InMemoryStorage,
        app: SessionApp? = nil,
        handler: @escaping @Sendable (URLRequest) -> StubTransport.Response
    ) -> (SessionStore, StubTransport) {
        let transport = StubTransport(handler: handler)
        let client = APIClient(
            configuration: APIConfiguration(baseURL: URL(string: "https://api.test")!) { "en" },
            session: transport.session
        )
        let store = SessionStore(client: client, keychain: storage, app: app)
        Task { await client.setTokenProvider(store) }
        return (store, transport)
    }

    @Test func startsRestoringSoTheUIDoesNotFlashSignIn() {
        let (store, _) = makeStore(storage: InMemoryStorage()) { _ in .json("{}") }
        #expect(store.phase == .restoring)
    }

    @Test func restoreWithNoStoredTokenSignsOut() async {
        let (store, transport) = makeStore(storage: InMemoryStorage()) { _ in .json("{}") }

        await store.restore()

        #expect(store.phase == .signedOut)
        #expect(transport.requests.isEmpty, "no stored token means nothing to ask the server")
    }

    @Test func devLoginPersistsTheRefreshTokenAndLoadsTheFullUser() async throws {
        let storage = InMemoryStorage()
        let (store, transport) = makeStore(storage: storage) { request in
            request.url?.path.hasSuffix("/me") == true ? .json(meBody) : .json(authBody)
        }

        try await store.signInWithDevLogin(email: "alice@example.com")

        #expect(store.phase == .signedIn(aliceClient))
        #expect(try storage.string(forKey: Self.refreshKey) == "refresh-1")
        #expect(await store.currentAccessToken() == "access-1")
        // /me is fetched rather than synthesised: the auth response's user has
        // no avatar_url.
        #expect(transport.requestCount(forPathSuffix: "/me") == 1)
    }

    // MARK: - App scope

    /// A session stored before the apps were scoped can be for the wrong
    /// role. It ends quietly rather than showing an explanation screen.
    @Test func restoreSignsOutAUserThisAppCannotServe() async throws {
        let storage = InMemoryStorage([Self.refreshKey: "refresh-0"])
        let (store, transport) = makeStore(storage: storage, app: .studio) { request in
            request.url?.path.hasSuffix("/me") == true
                ? .json(meBody)
                : .json(#"{"access_token":"access-2","refresh_token":"refresh-2"}"#)
        }

        await store.restore()

        #expect(store.phase == .signedOut)
        #expect(try storage.string(forKey: Self.refreshKey) == nil)
        #expect(transport.requests.contains { $0.httpMethod == "DELETE" }, "the refresh token is revoked too")
    }

    @Test func restoreKeepsAUserThisAppServes() async {
        let storage = InMemoryStorage([Self.refreshKey: "refresh-0"])
        let (store, _) = makeStore(storage: storage, app: .lactic) { request in
            request.url?.path.hasSuffix("/me") == true
                ? .json(meBody)
                : .json(#"{"access_token":"access-2","refresh_token":"refresh-2"}"#)
        }

        await store.restore()

        #expect(store.phase == .signedIn(aliceClient))
    }

    /// The backstop behind the API's own refusal: a user of the wrong role
    /// never reaches `.signedIn`, even for a moment.
    @Test func aSignInForTheWrongRoleThrowsAndLeavesNoSession() async throws {
        let storage = InMemoryStorage()
        let (store, transport) = makeStore(storage: storage, app: .studio) { request in
            request.url?.path.hasSuffix("/me") == true ? .json(meBody) : .json(authBody)
        }

        await #expect(throws: SessionStore.WrongAppError(role: .client)) {
            try await store.signIn(provider: "google", idToken: "tok")
        }
        #expect(store.phase != .signedIn(aliceClient))
        #expect(try storage.string(forKey: Self.refreshKey) == nil)

        let auth = try #require(transport.requests
            .first { $0.url?.path.hasSuffix("/auth") == true && $0.httpMethod == "POST" })
        let data = try #require(auth.bodyData())
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(body["app"] == "studio")
    }

    /// The API destroys the old refresh-token row when it issues a new pair, so
    /// two concurrent refreshes would leave one caller holding a token the
    /// server has already invalidated.
    @Test func concurrentRefreshesCollapseIntoOneRequest() async throws {
        let storage = InMemoryStorage([Self.refreshKey: "refresh-0"])
        let (store, transport) = makeStore(storage: storage) { _ in
            .json(#"{"access_token":"access-2","refresh_token":"refresh-2"}"#)
        }

        var tokens: [String?] = []
        await withTaskGroup(of: String?.self) { group in
            for _ in 0 ..< 8 {
                group.addTask { try? await store.refreshAccessToken() }
            }
            for await token in group {
                tokens.append(token)
            }
        }

        #expect(
            transport.requestCount(forPathSuffix: "/auth/refresh") == 1,
            "eight callers, one refresh"
        )
        #expect(tokens.allSatisfy { $0 == "access-2" })
        #expect(
            try storage.string(forKey: Self.refreshKey) == "refresh-2",
            "the rotated token must be persisted immediately"
        )
    }

    @Test func aRejectedRefreshEndsTheSession() async throws {
        let storage = InMemoryStorage([Self.refreshKey: "expired"])
        let (store, _) = makeStore(storage: storage) { _ in
            .json(#"{"error":"Invalid refresh token"}"#, status: 401)
        }

        let token = try await store.refreshAccessToken()

        #expect(token == nil)
        #expect(store.phase == .signedOut)
        #expect(try storage.string(forKey: Self.refreshKey) == nil, "a dead token must not linger")
    }

    @Test func restoreRecoversAnExistingSession() async throws {
        let storage = InMemoryStorage([Self.refreshKey: "refresh-0"])
        let (store, _) = makeStore(storage: storage) { request in
            request.url?.path.hasSuffix("/me") == true
                ? .json(meBody)
                : .json(#"{"access_token":"access-3","refresh_token":"refresh-3"}"#)
        }

        await store.restore()

        #expect(store.phase == .signedIn(aliceClient))
        #expect(try storage.string(forKey: Self.refreshKey) == "refresh-3")
    }

    @Test func signOutClearsEverythingEvenIfTheServerCallFails() async throws {
        let storage = InMemoryStorage([Self.refreshKey: "refresh-0"])
        let (store, _) = makeStore(storage: storage) { _ in .json(#"{"error":"boom"}"#, status: 500) }

        await store.signOut()

        #expect(store.phase == .signedOut)
        #expect(try storage.string(forKey: Self.refreshKey) == nil)
        #expect(await store.currentAccessToken() == nil)
    }
}
