import Foundation

public enum UserRole: String, Codable, Sendable, CaseIterable {
    case coach
    case client
}

/// `GET /api/v1/me` — `UserBlueprint`, five keys.
public struct User: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let email: String
    public let role: UserRole
    public let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email, role
        case avatarURL = "avatar_url"
    }
}

/// The user object returned by `POST /auth` and `/auth/dev_login`.
///
/// Deliberately a separate type from `User`: those actions hand-build a
/// four-key hash in the controller rather than rendering `UserBlueprint`, so
/// there is no `avatar_url`. Sharing one type would mean making `avatarURL`
/// optional everywhere and losing the guarantee that `/me` provides it.
public struct AuthUser: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let email: String
    public let role: UserRole
}

/// `POST /auth`, `POST /auth/dev_login`.
public struct AuthSession: Codable, Hashable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

/// `POST /auth/refresh`. Carries no user object, and **both** tokens rotate:
/// the old refresh token row is destroyed server-side, so the new one must be
/// persisted before the next request or the session is lost.
public struct RefreshedTokens: Codable, Hashable, Sendable {
    public let accessToken: String
    public let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
