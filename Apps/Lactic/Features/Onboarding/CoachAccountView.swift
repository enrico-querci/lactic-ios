import LacticKit
import LacticUI
import SwiftUI

/// Shown when a coach signs into the client app.
///
/// Roles are server-controlled and a user has exactly one, so a coach's token
/// is rejected by every `/client/**` endpoint with a 403. Without this the app
/// rendered "Forbidden" on every screen with a Retry button that could never
/// succeed — technically accurate, completely unactionable, and it looks like
/// the app is broken rather than like the account is the wrong kind.
///
/// The web has the same situation and routes coaches to `/coach/**`. There is
/// no coach experience here yet — Lactic Studio is a separate target — so the
/// honest answer is to explain and point at the dashboard that does exist.
struct CoachAccountView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.openURL) private var openURL

    let user: User

    /// Force-unwrapped like the base URLs in `AppEnvironment`: a literal that
    /// parses at every build or never. An `if let` here would let the button
    /// silently vanish instead of failing loudly.
    private static let coachDashboard = URL(string: "https://lactic-web.vercel.app/coach/programs")!

    var body: some View {
        VStack(spacing: LacticSpacing.lg) {
            Spacer()

            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(LacticColor.textMuted)

            VStack(spacing: LacticSpacing.sm) {
                Text("This is a coach account")
                    .font(.lacticTitle)
                    .foregroundStyle(LacticColor.textPrimary)
                    .multilineTextAlignment(.center)

                // Two sentences rather than one paragraph: the second names a
                // product the reader has to go and find, so it survives
                // translation better standing on its own.
                VStack(spacing: LacticSpacing.xs) {
                    Text("Lactic is where your clients follow the programmes you write.")
                    Text("Coaching tools live in Lactic Studio, which runs in the browser today.")
                }
                .font(.lacticBody)
                .foregroundStyle(LacticColor.textSecondary)
                .multilineTextAlignment(.center)
            }

            Text(user.email)
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textMuted)

            Spacer()

            VStack(spacing: LacticSpacing.sm) {
                Button("Open the coach dashboard") { openURL(Self.coachDashboard) }
                    .lacticButton()

                Button("Sign out") {
                    Task { await environment.session.signOut() }
                }
                .lacticButton(.secondary)
            }
        }
        .padding(LacticSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LacticColor.surface)
    }
}
