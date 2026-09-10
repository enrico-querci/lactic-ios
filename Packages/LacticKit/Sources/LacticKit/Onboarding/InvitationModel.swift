import Foundation
import LacticCore
import Observation

/// Drives the invitation screen: loads the invitation, works out which of the
/// four branches applies, and performs whichever action that branch offers.
///
/// `@MainActor @Observable` for the same reason as `SessionStore` — it is
/// observed directly by SwiftUI and every change it makes drives UI. The
/// networking happens inside `APIClient`, which is its own actor.
///
/// Deliberately holds no view state (no copy, no layout): the decision of what
/// to *show* is `step`, and how to show it belongs to the view.
@MainActor
@Observable
public final class InvitationModel {
    public private(set) var invitation: ClientInvitation?
    public private(set) var isLoading = false
    /// Separate from `isLoading` so a screen can keep the invitation on show
    /// while an Accept is in flight rather than collapsing to a spinner.
    public private(set) var isSubmitting = false
    public private(set) var failure: InvitationFailure?

    public let token: String

    @ObservationIgnored private let client: APIClient
    @ObservationIgnored private let session: SessionStore

    public init(token: String, client: APIClient, session: SessionStore) {
        self.token = token
        self.client = client
        self.session = session
    }

    /// `nil` until the invitation loads — there is nothing to decide before it.
    public var step: InvitationStep? {
        guard let invitation else { return nil }
        return InvitationFlow.step(for: invitation, signedInAs: session.phase.user)
    }

    public func load() async {
        isLoading = true
        failure = nil
        defer { isLoading = false }
        do {
            invitation = try await client.send(ClientAPI.invitation(token: token))
        } catch {
            // A bad token is a 404, which is the common case here — a mistyped
            // code or a truncated link — so it is reported as its own case
            // rather than as a generic failure of the app.
            invitation = nil
            failure = InvitationFailure(error)
        }
    }

    /// Accepts as the already signed-in client.
    ///
    /// The response is the updated user, carrying the `coach_id` the acceptance
    /// just set, so the session adopts it directly instead of re-fetching `/me`.
    public func accept() async -> Bool {
        guard !isSubmitting else { return false }
        isSubmitting = true
        failure = nil
        defer { isSubmitting = false }
        do {
            let user: User = try await client.send(ClientAPI.acceptInvitation(token: token))
            session.adopt(user)
            return true
        } catch {
            // The server re-checks everything this client already checked, and
            // it knows things the client cannot see — that the account is
            // already linked to a different coach, or that the invitation was
            // revoked a moment ago. Its message is the useful one.
            failure = InvitationFailure(error)
            await reloadAfterRejection()
            return false
        }
    }

    #if canImport(UIKit)
        /// Signs in and accepts in one step.
        ///
        /// The token rides along with the ID token because an unknown email
        /// *must* present one: without it the API would make this person a
        /// coach (§2.3), which is unrecoverable in production today.
        public func signInWithGoogle() async -> Bool {
            guard !isSubmitting else { return false }
            isSubmitting = true
            failure = nil
            defer { isSubmitting = false }
            do {
                try await session.signInWithGoogle(invitationToken: token)
                return true
            } catch is CancellationError {
                return false
            } catch {
                failure = InvitationFailure(error)
                await reloadAfterRejection()
                return false
            }
        }
    #endif

    /// Offered on the blocked branch, where the only way forward is to come
    /// back as somebody else.
    public func signOut() async {
        await session.signOut()
    }

    /// A rejected action usually means the invitation moved underneath us, so
    /// re-read it: the screen should stop offering Accept if it is now revoked.
    private func reloadAfterRejection() async {
        if let refreshed = try? await client.send(ClientAPI.invitation(token: token)) as ClientInvitation {
            invitation = refreshed
        }
    }
}
