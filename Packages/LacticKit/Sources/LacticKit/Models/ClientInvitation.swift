import Foundation

public enum InvitationStatus: String, Codable, Sendable, CaseIterable {
    case pending, expired, accepted, revoked
}

/// `GET /api/v1/client_invitations/:token`.
///
/// Unauthenticated and unredacted, and it returns 200 for accepted, revoked and
/// expired invitations too — the client has to branch on `status` itself rather
/// than treating a successful response as "this invitation is usable".
public struct ClientInvitation: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let email: String
    public let status: InvitationStatus
    public let expiresAt: Date
    public let sentAt: Date?
    public let createdAt: Date
    public let coachName: String

    enum CodingKeys: String, CodingKey {
        case id, email, status
        case expiresAt = "expires_at"
        case sentAt = "sent_at"
        case createdAt = "created_at"
        case coachName = "coach_name"
    }

    public var isPending: Bool {
        status == .pending
    }
}
