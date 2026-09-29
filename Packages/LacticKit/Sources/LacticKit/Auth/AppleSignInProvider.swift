import AuthenticationServices
import Foundation

/// Turns a Sign in with Apple authorization into what `POST /auth` needs.
///
/// Unlike Google there is no SDK and no presenter to find: the apps use
/// SwiftUI's `SignInWithAppleButton`, which runs the flow itself and hands back
/// an `ASAuthorization`. What is left is reading the credential correctly.
///
/// The API verifies the identity token against Apple's public keys, with the
/// app's bundle id as the audience. Nothing here trusts the token's contents.
public enum AppleSignInProvider {
    public enum Failure: Error, Equatable {
        case cancelled
        /// Apple's own flow failed. Its errors describe themselves as
        /// "AuthorizationError error 1000", which means nothing to a user, so
        /// they collapse into this for the screen to phrase. The usual causes
        /// are no Apple Account on the device or a build missing the
        /// entitlement.
        case failed
        case unexpectedCredential
        case missingIdentityToken
    }

    /// What the API needs from one authorization.
    public struct Credential: Equatable, Sendable {
        public let identityToken: String
        /// Single-use and valid for five minutes. The API exchanges it for the
        /// refresh token it revokes when the account is deleted, which App
        /// Review requires of every app offering Sign in with Apple.
        public let authorizationCode: String?
        /// Apple sends the name on the **first** authorization only, and never
        /// again — not even after a reinstall. Dropping it here loses it for
        /// good, so it always rides along when present.
        public let fullName: String?

        public init(identityToken: String, authorizationCode: String?, fullName: String?) {
            self.identityToken = identityToken
            self.authorizationCode = authorizationCode
            self.fullName = fullName
        }
    }

    /// Asks for a name and an email. The email is not optional in practice:
    /// the API matches invitations and existing accounts on it.
    public static func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    /// Reads the result `SignInWithAppleButton` delivers.
    ///
    /// Backing out of Apple's sheet arrives as an error; it becomes
    /// `Failure.cancelled` so callers can ignore it without inspecting domains.
    public static func credential(from result: Result<ASAuthorization, any Error>) throws -> Credential {
        switch result {
        case .success(let authorization):
            guard let appleID = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw Failure.unexpectedCredential
            }
            return try Self.credential(
                identityToken: appleID.identityToken,
                authorizationCode: appleID.authorizationCode,
                fullName: appleID.fullName
            )
        case .failure(let error):
            throw failure(for: error)
        }
    }

    /// Split from `credential(from:)` because `ASAuthorization` has no public
    /// initializer, so this is the part a test can reach.
    static func credential(
        identityToken: Data?,
        authorizationCode: Data?,
        fullName: PersonNameComponents?
    ) throws -> Credential {
        guard let identityToken, let token = String(data: identityToken, encoding: .utf8), !token.isEmpty else {
            throw Failure.missingIdentityToken
        }
        return Credential(
            identityToken: token,
            authorizationCode: authorizationCode.flatMap { String(data: $0, encoding: .utf8) },
            fullName: displayName(from: fullName)
        )
    }

    /// Every later sign-in delivers empty components rather than `nil`, which
    /// would otherwise format as an empty string and overwrite nothing useful.
    static func displayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let name = components.formatted(.name(style: .medium))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    static func failure(for error: any Error) -> any Error {
        let nsError = error as NSError
        guard nsError.domain == ASAuthorizationError.errorDomain else { return error }
        return nsError.code == ASAuthorizationError.canceled.rawValue ? Failure.cancelled : Failure.failed
    }
}
