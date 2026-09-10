import Foundation
import LacticCore
import Testing
@testable import LacticKit

private func makeUser(email: String, role: UserRole = .client) throws -> User {
    let json = #"{"id":1,"name":"Alice","email":"\#(email)","role":"\#(role.rawValue)","avatar_url":null}"#
    return try JSONDecoder().decode(User.self, from: Data(json.utf8))
}

private func makeInvitation(email: String, status: InvitationStatus = .pending) throws -> ClientInvitation {
    let json = """
    {"id":7,"email":"\(email)","status":"\(status.rawValue)","expires_at":"2026-12-01T00:00:00.000Z",
     "sent_at":null,"created_at":"2026-09-01T00:00:00.000Z","coach_name":"John"}
    """
    return try JSONCoding.decoder.decode(ClientInvitation.self, from: Data(json.utf8))
}

struct InvitationStepTests {
    @Test func signedOutIsAskedToSignIn() throws {
        let step = try InvitationFlow.step(for: makeInvitation(email: "a@example.com"), signedInAs: nil)
        #expect(step == .signInRequired)
    }

    @Test func theInvitedClientCanAccept() throws {
        let step = try InvitationFlow.step(
            for: makeInvitation(email: "a@example.com"),
            signedInAs: makeUser(email: "a@example.com")
        )
        #expect(step == .readyToAccept)
    }

    @Test func aDifferentClientIsNamedRatherThanJustRefused() throws {
        let step = try InvitationFlow.step(
            for: makeInvitation(email: "invited@example.com"),
            signedInAs: makeUser(email: "someone@example.com")
        )
        #expect(step == .blocked(.differentEmail, signedInAs: "someone@example.com", invited: "invited@example.com"))
    }

    /// The server refuses this in `ClientInvitations::Accept`, so the client
    /// must not offer an Accept button that can only 422.
    @Test func aCoachCannotAcceptEvenWithAMatchingEmail() throws {
        let step = try InvitationFlow.step(
            for: makeInvitation(email: "same@example.com"),
            signedInAs: makeUser(email: "same@example.com", role: .coach)
        )
        #expect(step == .blocked(.coachAccount, signedInAs: "same@example.com", invited: "same@example.com"))
    }

    /// Status wins over the account: an expired invitation is unusable even for
    /// exactly the right person.
    @Test(arguments: [InvitationStatus.expired, .revoked, .accepted])
    func anUnusableInvitationIsTerminal(status: InvitationStatus) throws {
        let step = try InvitationFlow.step(
            for: makeInvitation(email: "a@example.com", status: status),
            signedInAs: makeUser(email: "a@example.com")
        )
        #expect(step == .unavailable(status))
    }
}

struct InvitationEmailTests {
    @Test func comparisonIgnoresCaseAndSurroundingSpace() {
        #expect(InvitationEmail.matches("  Alice@Example.com ", "alice@example.com"))
    }

    /// Mirrors the server, which folds Gmail's ignored dots and "+" tags. The
    /// web compares naively and shows these clients a dead end.
    @Test(arguments: [
        ("john.doe@gmail.com", "johndoe@gmail.com"),
        ("johndoe+gym@gmail.com", "johndoe@gmail.com"),
        ("j.o.h.n.doe+a+b@googlemail.com", "johndoe@googlemail.com"),
    ])
    func gmailDotsAndTagsFold(signedIn: String, invited: String) {
        #expect(InvitationEmail.matches(signedIn, invited))
    }

    /// Only Gmail folds. Everywhere else a dot is a real character, so folding
    /// would match two genuinely different mailboxes.
    @Test func otherDomainsKeepDotsAndTags() {
        #expect(!InvitationEmail.matches("john.doe@example.com", "johndoe@example.com"))
        #expect(!InvitationEmail.matches("johndoe+gym@example.com", "johndoe@example.com"))
    }

    @Test func aValueWithoutAnAtSignIsLeftAlone() {
        #expect(InvitationEmail.normalize("not-an-email") == "not-an-email")
    }
}

struct InvitationLinkTests {
    @Test func readsTheTokenFromAWebLink() throws {
        let url = try #require(URL(string: "https://lactic-web.vercel.app/invite/abc123-_="))
        #expect(InvitationLink.token(from: url) == "abc123-_=")
    }

    @Test func readsTheTokenFromACustomScheme() throws {
        let url = try #require(URL(string: "lactic://invite/abc123"))
        #expect(InvitationLink.token(from: url) == "abc123")
    }

    /// A preview or staging deployment serves the same path on another host,
    /// and only the API can judge whether a token is real.
    @Test func acceptsAnyHost() throws {
        let url = try #require(URL(string: "https://lactic-web-git-preview.vercel.app/invite/abc123"))
        #expect(InvitationLink.token(from: url) == "abc123")
    }

    @Test func ignoresUnrelatedLinks() throws {
        let url = try #require(URL(string: "https://lactic-web.vercel.app/client/programs"))
        #expect(InvitationLink.token(from: url) == nil)
    }

    @Test func ignoresALinkWithNoTokenAfterTheMarker() throws {
        let url = try #require(URL(string: "https://lactic-web.vercel.app/invite"))
        #expect(InvitationLink.token(from: url) == nil)
    }

    @Test func acceptsAPastedLinkOrABareCode() {
        #expect(InvitationLink.token(fromPastedText: " https://lactic-web.vercel.app/invite/abc123 ") == "abc123")
        #expect(InvitationLink.token(fromPastedText: "  abc123  ") == "abc123")
    }

    @Test func rejectsPastedTextThatCannotBeAToken() {
        #expect(InvitationLink.token(fromPastedText: "") == nil)
        #expect(InvitationLink.token(fromPastedText: "two words") == nil)
        #expect(InvitationLink.token(fromPastedText: "https://lactic-web.vercel.app/login") == nil)
    }
}
