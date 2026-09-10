import Foundation
import LacticCore

/// A coach's billing plan, from `GET /api/v1/coach/subscription`.
///
/// Assembled by the controller rather than rendered from a blueprint, and
/// `plan` is already resolved against `expires_at` — a lapsed subscription
/// reports `free` rather than its old tier. So this is what the coach is
/// entitled to *now*; it is not a mirror of the `CoachSubscription` row.
public struct CoachSubscription: Codable, Hashable, Sendable {
    public let plan: SubscriptionPlan
    /// `nil` means unlimited: either a paid unlimited tier or a comped email
    /// on `COACH_EMAILS`.
    public let clientLimit: Int?
    public let clientSlotsUsed: Int
    public let expiresAt: Date?
    public let autoRenew: Bool?
    public let billingIssue: Bool

    enum CodingKeys: String, CodingKey {
        case plan
        case clientLimit = "client_limit"
        case clientSlotsUsed = "client_slots_used"
        case expiresAt = "expires_at"
        case autoRenew = "auto_renew"
        case billingIssue = "billing_issue"
    }

    /// Whether another client can be invited. The server decides this too and
    /// answers 402 — this only exists so the UI can say so before asking.
    public var canInviteClient: Bool {
        guard let clientLimit else { return true }
        return clientSlotsUsed < clientLimit
    }
}

/// Kept as a closed set with an escape hatch: the API can add a tier before
/// this app ships an update, and an unknown plan must not make the whole
/// subscription undecodable — that would lock a paying coach out of billing.
public enum SubscriptionPlan: RawRepresentable, Codable, Hashable, Sendable {
    case free
    case pro
    case proPlus
    case unlimited
    case founding
    case other(String)

    public init(rawValue: String) {
        switch rawValue {
        case "free": self = .free
        case "pro": self = .pro
        case "pro_plus": self = .proPlus
        case "unlimited": self = .unlimited
        case "founding": self = .founding
        default: self = .other(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .free: "free"
        case .pro: "pro"
        case .proPlus: "pro_plus"
        case .unlimited: "unlimited"
        case .founding: "founding"
        case .other(let value): value
        }
    }
}

/// A saved workout, reusable outside the program it came from.
public struct WorkoutTemplate: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let sourceWorkoutID: Int
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case sourceWorkoutID = "source_workout_id"
        case createdAt = "created_at"
    }
}
