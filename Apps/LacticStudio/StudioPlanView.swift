import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// The coach's plan and how much of it is used — the web's billing page
/// without its checkout.
///
/// Read-only on purpose. Selling or linking to a subscription from inside the
/// app is an unresolved App Review question (AGENTS.md §8,
/// docs/studio-ui-brief.md §6), and getting it wrong could keep Studio off
/// the store. Plans are bought on the web; this section only reports.
struct StudioPlanSection: View {
    @Environment(StudioEnvironment.self) private var environment
    let roster: ClientListModel

    var body: some View {
        if let subscription = roster.subscription {
            content(subscription)
        } else if let failure = roster.failure {
            VStack(spacing: LacticSpacing.lg) {
                StudioActionFailureNotice(failure: failure)
                Button("Try again") { Task { await roster.load() } }
                    .lacticButton(.secondary)
                    .frame(maxWidth: 240)
            }
        } else {
            LoadingView(String(localized: "Loading your plan"))
                .frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    private func content(_ subscription: CoachSubscription) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.xl) {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                Text("Current plan")
                    .font(.lacticEyebrow)
                    .foregroundStyle(LacticColor.brand)
                    .textCase(.uppercase)
                Text(verbatim: subscription.plan.label)
                    .font(.lacticDisplay)
                    .foregroundStyle(LacticColor.textOnHero)
                if let expiresAt = subscription.expiresAt {
                    Group {
                        if subscription.autoRenew == false {
                            Text("Ends on \(Formatters.date(expiresAt, locale: environment.locale))")
                        } else {
                            Text("Renews on \(Formatters.date(expiresAt, locale: environment.locale))")
                        }
                    }
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textOnHero.opacity(0.78))
                }
            }
            .padding(LacticSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LacticColor.heroSurface,
                in: RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
            )

            if subscription.billingIssue {
                Label {
                    Text(
                        "There's a problem with your latest payment. Update your payment method to keep your plan."
                    )
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(LacticColor.warning)
                }
                .font(.lacticBody)
                .padding(LacticSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LacticColor.warningSurface,
                    in: RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                )
            }

            usage(subscription)

            Text("""
            Your plan sets how many clients you can have, counting pending invitations. \
            If it lapses, your existing clients keep everything; only new invitations wait.
            """)
            .font(.lacticCaption)
            .foregroundStyle(LacticColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func usage(_ subscription: CoachSubscription) -> some View {
        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            Text("Client slots")
                .font(.lacticHeadline)
            if let limit = subscription.clientLimit {
                Text("\(subscription.clientSlotsUsed) of \(limit) clients")
                    .font(.title2.weight(.bold).monospacedDigit())
                ProgressView(value: Double(min(subscription.clientSlotsUsed, limit)), total: Double(max(limit, 1)))
                    .tint(subscription.canInviteClient ? LacticColor.accent : LacticColor.warning)
            } else {
                Text("\(subscription.clientSlotsUsed) clients · unlimited")
                    .font(.title2.weight(.bold).monospacedDigit())
            }
        }
        .studioCard()
        .accessibilityElement(children: .combine)
    }
}
