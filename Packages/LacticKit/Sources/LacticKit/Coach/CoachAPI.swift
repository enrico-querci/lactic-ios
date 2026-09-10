import Foundation
import LacticCore

/// Every `/api/v1/coach/**` endpoint, as `Endpoint` values.
///
/// Written out in full even though Lactic Studio v1 builds only sign-in and
/// the client list: the models already exist, so the rest is cheap now and
/// expensive to interleave later.
///
/// Two conventions worth knowing, because they are not uniform on the server:
/// most writes wrap their payload in a Rails root key (`program`, `week`,
/// `workout`, `workout_exercise`, `exercise`, `program_assignment`), while
/// invitations and workout templates take their parameters at the top level.
/// Each is matched to what its controller actually permits.
public enum CoachAPI {
    // MARK: - Clients

    public static var clients: Endpoint {
        Endpoint(path: "/coach/clients")
    }

    public static func client(id: Int) -> Endpoint {
        Endpoint(path: "/coach/clients/\(id)")
    }

    /// Unlinks a client. Their logged history is not deleted.
    public static func removeClient(id: Int) -> Endpoint {
        Endpoint(method: .delete, path: "/coach/clients/\(id)")
    }

    /// A client's sessions, newest first — the same shape the client's own
    /// history returns, including `workout_name`.
    public static func clientProgress(clientID: Int) -> Endpoint {
        Endpoint(path: "/coach/clients/\(clientID)/progress")
    }

    public static func clientSession(clientID: Int, sessionID: Int) -> Endpoint {
        Endpoint(path: "/coach/clients/\(clientID)/progress/\(sessionID)")
    }

    // MARK: - Client invitations

    public static var invitations: Endpoint {
        Endpoint(path: "/coach/client_invitations")
    }

    /// Invites a client by email.
    ///
    /// Answers **402 with `client_limit_reached`** when the coach's plan is
    /// full — the one billing state Studio has to handle, since it is the only
    /// thing a lapsed subscription actually blocks. `APIError.code` carries it.
    /// Also 422 for a coach's own address or an existing client of this coach,
    /// and 409 when the person already belongs to another coach.
    ///
    /// `email` is top level, not wrapped: the controller reads
    /// `params.require(:email)`.
    public static func createInvitation(email: String) throws -> Endpoint {
        try Endpoint(
            method: .post, path: "/coach/client_invitations",
            body: JSONCoding.encoder.encode(["email": email])
        )
    }

    /// Rotates the token and expiry, and sends the email again.
    public static func resendInvitation(id: Int) -> Endpoint {
        Endpoint(method: .post, path: "/coach/client_invitations/\(id)/resend")
    }

    public static func revokeInvitation(id: Int) -> Endpoint {
        Endpoint(method: .delete, path: "/coach/client_invitations/\(id)")
    }

    // MARK: - Subscription

    public static var subscription: Endpoint {
        Endpoint(path: "/coach/subscription")
    }

    /// Re-fetches entitlements from RevenueCat and upserts the stored plan, so
    /// a new purchase applies without waiting on webhook delivery. Answers 503
    /// when billing is unconfigured and 502 when RevenueCat cannot be reached.
    public static var syncSubscription: Endpoint {
        Endpoint(method: .post, path: "/coach/subscription/sync")
    }

    // MARK: - Encoding

    struct CreateTemplate: Encodable {
        let name: String
        let sourceWorkoutID: Int
        enum CodingKeys: String, CodingKey {
            case name
            case sourceWorkoutID = "source_workout_id"
        }
    }

    struct ApplyTemplate: Encodable {
        let targetWeekID: Int
        enum CodingKeys: String, CodingKey {
            case targetWeekID = "target_week_id"
        }
    }

    /// Wraps a payload in its Rails root key, dropping nil values so a PATCH
    /// only sends the fields it means to change — sending an explicit null
    /// would clear a column the caller never mentioned.
    static func encode(_ key: String, _ fields: [String: (any Encodable & Sendable)?]) throws -> Data {
        let present = fields.compactMapValues { $0 }.mapValues(AnyEncodable.init)
        return try JSONCoding.encoder.encode([key: present])
    }
}

/// Erases a heterogeneous payload so one dictionary can carry strings, numbers
/// and decimals without a generic parameter per call site.
private struct AnyEncodable: Encodable {
    private let encodeValue: @Sendable (inout any SingleValueEncodingContainer) throws -> Void

    init(_ wrapped: any Encodable & Sendable) {
        encodeValue = { container in try container.encode(wrapped) }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try encodeValue(&container)
    }
}
