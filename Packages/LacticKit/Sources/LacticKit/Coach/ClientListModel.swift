import Foundation
import LacticCore
import Observation

/// Why a coach-side action was refused.
///
/// A reason rather than a sentence, for the same purpose as
/// `InvitationFailure`: LacticKit ships no string catalog, so prose from here
/// would put untranslatable English in front of an Italian coach. `rejected`
/// is the exception, carrying the API's own per-case message.
public enum CoachActionFailure: Equatable, Sendable {
    /// 402 `client_limit_reached` — the only billing state that blocks
    /// anything, and the only one worth its own screen state because the way
    /// out is upgrading rather than correcting the input.
    case planIsFull
    case offline
    /// Everything the server refuses with a reason worth reading: an address
    /// that is already this coach's client, one that belongs to another coach,
    /// or a coach account being invited as a client.
    case rejected(String)

    public init(_ error: any Error) {
        guard let apiError = error as? APIError else {
            self = .rejected(error.localizedDescription)
            return
        }
        switch apiError {
        case .transport:
            self = .offline
        case _ where apiError.code == "client_limit_reached":
            self = .planIsFull
        default:
            self = .rejected(apiError.message)
        }
    }
}

/// The coach's client roster: who they train, who they have invited, and how
/// much of their plan that uses.
///
/// One model rather than three because the screen is one list and the three
/// are interdependent — inviting consumes a slot, revoking returns one, and
/// the plan decides whether the invite control is offered at all.
@MainActor
@Observable
public final class ClientListModel {
    public private(set) var clients: [User] = []
    public private(set) var invitations: [ClientInvitation] = []
    public private(set) var subscription: CoachSubscription?

    public private(set) var isLoading = false
    /// Separate from `isLoading` so the list stays on screen while an invite
    /// or a revoke is in flight, rather than collapsing to a spinner.
    public private(set) var isSubmitting = false
    public private(set) var failure: CoachActionFailure?

    @ObservationIgnored private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// Only pending invitations can be resent or revoked; the rest are history.
    public var pendingInvitations: [ClientInvitation] {
        invitations.filter(\.isPending)
    }

    /// Whether to offer the invite control at all.
    ///
    /// The server decides this too and answers 402, so this is not a guard —
    /// it exists so a full plan reads as a plan state rather than as a failed
    /// action. Unknown until the subscription loads, and permissive then:
    /// hiding the control because a fetch failed would be worse than a 402.
    public var canInviteClient: Bool {
        subscription?.canInviteClient ?? true
    }

    public func load() async {
        isLoading = true
        failure = nil
        defer { isLoading = false }
        do {
            // Concurrently: three independent reads, and the screen needs all
            // three before it can show a roster with its plan usage.
            async let clients: [User] = client.send(CoachAPI.clients)
            async let invitations: [ClientInvitation] = client.send(CoachAPI.invitations)
            async let subscription: CoachSubscription = client.send(CoachAPI.subscription)
            (self.clients, self.invitations, self.subscription) =
                try await (clients, invitations, subscription)
        } catch {
            failure = CoachActionFailure(error)
        }
    }

    /// Invites a client by email.
    ///
    /// On success the new invitation is merged in rather than the whole screen
    /// reloaded, so the list does not flicker. A 402 refreshes the plan, so the
    /// usage the coach is shown matches the refusal they just got.
    @discardableResult
    public func invite(email: String) async -> Bool {
        await perform {
            let invitation: ClientInvitation = try await self.client.send(
                CoachAPI.createInvitation(email: email)
            )
            self.invitations.insert(invitation, at: 0)
        }
    }

    /// Rotates the token and expiry and sends the email again, so the returned
    /// invitation replaces the one on screen.
    @discardableResult
    public func resend(invitationID: Int) async -> Bool {
        await perform {
            let invitation: ClientInvitation = try await self.client.send(
                CoachAPI.resendInvitation(id: invitationID)
            )
            self.replace(invitation)
        }
    }

    @discardableResult
    public func revoke(invitationID: Int) async -> Bool {
        await perform {
            try await self.client.sendIgnoringResponse(CoachAPI.revokeInvitation(id: invitationID))
            self.invitations.removeAll { $0.id == invitationID }
            // Revoking returns a slot, so the plan usage on screen is now stale.
            await self.refreshSubscription()
        }
    }

    /// Unlinks a client. Their logged history is not deleted — the server keeps
    /// it, and the coach is only losing access.
    @discardableResult
    public func removeClient(id: Int) async -> Bool {
        await perform {
            try await self.client.sendIgnoringResponse(CoachAPI.removeClient(id: id))
            self.clients.removeAll { $0.id == id }
            await self.refreshSubscription()
        }
    }

    // MARK: - Internals

    private func replace(_ invitation: ClientInvitation) {
        if let index = invitations.firstIndex(where: { $0.id == invitation.id }) {
            invitations[index] = invitation
        } else {
            invitations.insert(invitation, at: 0)
        }
    }

    /// Best effort: a stale slot count is a cosmetic problem, and failing the
    /// action the coach actually asked for would not be.
    private func refreshSubscription() async {
        subscription = try? await client.send(CoachAPI.subscription)
    }

    private func perform(_ work: @escaping () async throws -> Void) async -> Bool {
        guard !isSubmitting else { return false }
        isSubmitting = true
        failure = nil
        defer { isSubmitting = false }
        do {
            try await work()
            return true
        } catch {
            let failure = CoachActionFailure(error)
            self.failure = failure
            if failure == .planIsFull {
                // Show the usage that justifies the refusal, not the stale one.
                await refreshSubscription()
            }
            return false
        }
    }
}
