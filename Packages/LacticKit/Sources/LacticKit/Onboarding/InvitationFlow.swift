import Foundation

/// Why a signed-in account cannot accept the invitation in front of it.
///
/// Two distinct causes with two distinct remedies, so they stay separate rather
/// than collapsing into one "wrong account": a mismatched email can be fixed by
/// signing in as the invited address, while a coach account cannot accept a
/// client invitation at all.
public enum InvitationBlock: Equatable, Sendable {
    case differentEmail
    case coachAccount
}

/// What the invitation screen should offer, given the invitation and who — if
/// anyone — is signed in.
///
/// Mirrors the four branches in `lactic-web/app/invite/[token]/page.tsx`.
public enum InvitationStep: Equatable, Sendable {
    /// Accepted, revoked or expired. Terminal: the coach has to send a new one.
    case unavailable(InvitationStatus)
    /// Nobody signed in. Sign in with Google carrying the token, which is what
    /// creates the client account in the first place.
    case signInRequired
    /// Signed in as the invited client. One `POST …/accept` away.
    case readyToAccept
    /// Signed in as somebody who cannot accept this invitation.
    case blocked(InvitationBlock, signedInAs: String, invited: String)
}

public enum InvitationFlow {
    /// Decides the step. Pure, so every branch is a unit test rather than a
    /// simulator session.
    ///
    /// `status` is checked before the account, matching the server: an expired
    /// invitation is unusable no matter who is looking at it.
    public static func step(for invitation: ClientInvitation, signedInAs user: User?) -> InvitationStep {
        guard invitation.isPending else {
            return .unavailable(invitation.status)
        }
        guard let user else {
            return .signInRequired
        }
        guard user.role == .client else {
            return .blocked(.coachAccount, signedInAs: user.email, invited: invitation.email)
        }
        guard InvitationEmail.matches(user.email, invitation.email) else {
            return .blocked(.differentEmail, signedInAs: user.email, invited: invitation.email)
        }
        return .readyToAccept
    }
}

/// Email comparison for invitation acceptance.
///
/// Deliberately mirrors `ClientInvitations::Accept.normalize_for_comparison`
/// rather than `lactic-web`, which compares with a plain `toLowerCase()`. The
/// server is the authority: it folds Gmail's ignored dots and `+` tags, so a
/// client invited as `johndoe@gmail.com` who signs in as `john.doe+gym@gmail.com`
/// *is* accepted. Comparing naively here would show that client a "wrong
/// account" dead end for an invitation the server would have taken — which is
/// what the web does today.
public enum InvitationEmail {
    /// Gmail ignores dots and anything after `+` when routing, and reports one
    /// canonical form as the verified OAuth email. Every other domain treats
    /// both as significant, so only these are folded.
    private static let foldedDomains: Set<String> = ["gmail.com", "googlemail.com"]

    public static func matches(_ lhs: String, _ rhs: String) -> Bool {
        normalize(lhs) == normalize(rhs)
    }

    public static func normalize(_ email: String) -> String {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Split on the last "@": a local part may legally contain one when
        // quoted, and the domain never can.
        guard let at = trimmed.lastIndex(of: "@") else { return trimmed }
        let local = String(trimmed[trimmed.startIndex ..< at])
        let domain = String(trimmed[trimmed.index(after: at)...])
        guard foldedDomains.contains(domain) else { return trimmed }
        let untagged = local.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        return "\(untagged.replacingOccurrences(of: ".", with: ""))@\(domain)"
    }
}

/// Extracts an invitation token from whatever the client arrives with.
///
/// Universal Links need an Apple Team ID and an `apple-app-site-association`
/// file on `lactic-web`, so today the realistic entries are a pasted link and a
/// pasted code. Parsing is written against the URL shape anyway, so turning
/// Universal Links on later is configuration rather than new logic.
public enum InvitationLink {
    /// The path segment the web portal uses: `${FRONTEND_URL}/invite/<token>`.
    private static let pathMarker = "invite"

    /// Reads a token out of a URL, accepting both the web link and a custom
    /// scheme (`lactic://invite/<token>`), from any host — the API is the only
    /// thing that can say whether a token is real, so refusing an unexpected
    /// host here would just reject links from a staging or preview deployment.
    public static func token(from url: URL) -> String? {
        var segments = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        // A custom scheme puts "invite" in the host rather than the path.
        if let host = url.host, host.lowercased() == pathMarker {
            return segments.first.flatMap(sanitized)
        }
        guard let marker = segments.firstIndex(where: { $0.lowercased() == pathMarker }) else {
            return nil
        }
        segments.removeSubrange(...marker)
        return segments.first.flatMap(sanitized)
    }

    /// Reads a token out of text the client pasted — either a full link or the
    /// bare code, since an emailed link is as likely to be copied whole as it
    /// is to be tapped.
    public static func token(fromPastedText text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("://"), let url = URL(string: trimmed) {
            return token(from: url)
        }
        return sanitized(trimmed)
    }

    /// Tokens are `SecureRandom.urlsafe_base64(32)`, so they are URL-safe
    /// base64 today. Validating the character set rather than the length keeps
    /// this from breaking if the server ever changes token width.
    private static func sanitized(_ candidate: String) -> String? {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=")
        guard !candidate.isEmpty, candidate.unicodeScalars.allSatisfy(allowed.contains) else {
            return nil
        }
        return candidate
    }
}

/// Why an invitation action did not succeed.
///
/// A reason rather than a sentence: LacticKit ships no string catalog, so
/// returning prose from here would put untranslatable English in front of an
/// Italian client. The one exception is `server`, which carries the API's own
/// message — that text is written per-case by the server and is the useful
/// thing to show, exactly as `lactic-web` shows it.
public enum InvitationFailure: Equatable, Sendable {
    /// No invitation for this token: usually a mistyped code or a cut-off link.
    case notFound
    case offline
    case server(String)

    public init(_ error: any Error) {
        guard let apiError = error as? APIError else {
            self = .server(error.localizedDescription)
            return
        }
        switch apiError {
        case .transport: self = .offline
        case _ where apiError.status == 404: self = .notFound
        default: self = .server(apiError.message)
        }
    }
}
