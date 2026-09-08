import Foundation
import LacticCore
import Observation

/// What the UI needs to know about the session.
public enum AuthPhase: Equatable, Sendable {
    /// Before `restore()` has finished. Distinct from `signedOut` so the app
    /// can show a splash rather than flashing the sign-in screen at a user who
    /// turns out to be signed in.
    case restoring
    case signedOut
    case signedIn(User)
}

/// Owns the session: which user is signed in, and the tokens that prove it.
///
/// `@MainActor` because it is observed directly by SwiftUI and its state
/// changes always drive UI. The work it does off the main thread is the network
/// call inside `APIClient`, which is its own actor; what happens here is a
/// keychain read and a couple of assignments.
@MainActor
@Observable
public final class SessionStore: TokenProviding {
    public private(set) var phase: AuthPhase = .restoring

    /// In memory only, exactly like the web client. It lives 15 minutes, so
    /// persisting it would add exposure for almost no benefit.
    @ObservationIgnored private var accessToken: String?

    /// Persisted, because it is what survives a relaunch. In the keychain
    /// rather than UserDefaults: a plist in the app container is readable from
    /// an unencrypted backup.
    @ObservationIgnored private let keychain: any SecureStorage
    @ObservationIgnored private let client: APIClient
    @ObservationIgnored private var refreshTask: Task<String?, any Error>?

    private static let refreshTokenKey = "refresh_token"

    public init(
        client: APIClient,
        keychain: any SecureStorage = KeychainStore(service: "com.enricoquerci.lactic.session")
    ) {
        self.client = client
        self.keychain = keychain
    }

    // MARK: - Lifecycle

    /// Restores a session at launch, mirroring the web's boot sequence: the
    /// stored refresh token is exchanged for a fresh pair, then `/me` supplies
    /// the user. Any failure means signed out rather than an error screen —
    /// there is nothing the user could do about it but sign in again.
    public func restore() async {
        guard let stored = storedRefreshToken, !stored.isEmpty else {
            phase = .signedOut
            return
        }
        do {
            _ = try await performRefresh(using: stored)
            let user: User = try await client.send(ClientAPI.me)
            phase = .signedIn(user)
        } catch {
            AppLog.auth.info("Session restore failed; signing out")
            await clearSession()
        }
    }

    /// Development-only sign-in. The route does not exist in production, which
    /// is precisely why it is safe to ship this call: a Release build pointed at
    /// production gets a 404, not a back door.
    public func signInWithDevLogin(email: String) async throws {
        let session: AuthSession = try await client.send(ClientAPI.devLogin(email: email))
        try apply(session)
        // The auth response carries a four-key user with no avatar_url, so read
        // the full record rather than synthesising one from it.
        let user: User = try await client.send(ClientAPI.me)
        phase = .signedIn(user)
    }

    public func signIn(provider: String, idToken: String, invitationToken: String? = nil) async throws {
        let endpoint = try ClientAPI.signIn(
            provider: provider, idToken: idToken, invitationToken: invitationToken
        )
        let session: AuthSession = try await client.send(endpoint)
        try apply(session)
        let user: User = try await client.send(ClientAPI.me)
        phase = .signedIn(user)
    }

    public func signOut() async {
        if let token = storedRefreshToken, !token.isEmpty {
            // Best effort: the endpoint always answers 204 and revokes only the
            // token presented, so a failure here costs nothing locally.
            _ = try? await client.sendIgnoringResponse(try ClientAPI.signOut(refreshToken: token))
        }
        await clearSession()
    }

    // MARK: - TokenProviding

    public func currentAccessToken() async -> String? {
        accessToken
    }

    /// Refreshes once, however many callers ask at once.
    ///
    /// Coalescing is not a nicety here. The API destroys the old refresh-token
    /// row when it issues a new pair, so two concurrent refreshes would leave
    /// one holding a token the server has already invalidated, and that caller
    /// would be signed out for no reason.
    public func refreshAccessToken() async throws -> String? {
        if let refreshTask {
            return try await refreshTask.value
        }

        guard let stored = storedRefreshToken, !stored.isEmpty else {
            await clearSession()
            return nil
        }

        let task = Task<String?, any Error> { [weak self] in
            guard let self else { return nil }
            return try await performRefresh(using: stored)
        }
        refreshTask = task
        defer { refreshTask = nil }

        do {
            return try await task.value
        } catch {
            AppLog.auth.info("Refresh failed; session is over")
            await clearSession()
            return nil
        }
    }

    public func clearSession() async {
        accessToken = nil
        try? keychain.set(nil, forKey: Self.refreshTokenKey)
        phase = .signedOut
    }

    // MARK: - Internals

    private var storedRefreshToken: String? {
        try? keychain.string(forKey: Self.refreshTokenKey)
    }

    @discardableResult
    private func performRefresh(using refreshToken: String) async throws -> String {
        let tokens: RefreshedTokens = try await client.send(ClientAPI.refresh(refreshToken: refreshToken))
        accessToken = tokens.accessToken
        // Persist the rotated token immediately: the one just used is already
        // dead server-side, so a crash between here and the next request would
        // otherwise strand the session.
        try keychain.set(tokens.refreshToken, forKey: Self.refreshTokenKey)
        return tokens.accessToken
    }

    private func apply(_ session: AuthSession) throws {
        accessToken = session.accessToken
        try keychain.set(session.refreshToken, forKey: Self.refreshTokenKey)
    }
}
