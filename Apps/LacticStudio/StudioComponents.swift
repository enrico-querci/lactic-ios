import LacticCore
import LacticKit
import LacticUI
import SwiftUI

// Building blocks every Studio destination shares, so the roster, the
// programme builder and the rest read as one product.

struct StudioSidebarRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: LocalizedStringKey
    let compactTitle: LocalizedStringKey
    let systemImage: String
    /// `nil` for a destination that is not a collection, like Profile.
    let count: Int?

    var body: some View {
        HStack(spacing: LacticSpacing.sm) {
            Label(
                dynamicTypeSize.isAccessibilitySize ? compactTitle : title,
                systemImage: systemImage
            )
            .lineLimit(1)
            .accessibilityLabel(title)
            Spacer(minLength: LacticSpacing.sm)
            if let count {
                Text(verbatim: count.formatted())
                    .font(.lacticCaption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(LacticColor.textSecondary)
                    .padding(.horizontal, LacticSpacing.sm)
                    .padding(.vertical, LacticSpacing.xs)
                    .background(LacticColor.surfacePressed, in: Capsule())
            }
        }
        .frame(minHeight: LacticSize.minimumHitTarget)
    }
}

struct StudioDashboardHeader: View {
    let eyebrow: LocalizedStringKey
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: LacticSpacing.sm) {
            Text(eyebrow)
                .font(.lacticEyebrow)
                .foregroundStyle(LacticColor.brand)
                .textCase(.uppercase)
            Text(title)
                .font(.lacticDisplay)
                .foregroundStyle(LacticColor.textOnHero)
            Text(message)
                .font(.lacticBody)
                .foregroundStyle(LacticColor.textOnHero.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LacticColor.heroSurface,
            in: RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
        )
    }
}

struct StudioMetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String
    /// A single line — icon, label, value at the trailing edge — for stacked
    /// layouts, where a card is a full-width row rather than a tile.
    var isRow = false

    var body: some View {
        HStack(spacing: LacticSpacing.md) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(LacticColor.accent)
                .frame(width: LacticSize.minimumHitTarget, height: LacticSize.minimumHitTarget)
                .background(LacticColor.surfacePressed, in: Circle())
                .accessibilityHidden(true)

            if isRow {
                Text(title)
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textSecondary)
                Spacer(minLength: LacticSpacing.sm)
                Text(verbatim: value)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(LacticColor.textPrimary)
            } else {
                VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                    Text(verbatim: value)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(LacticColor.textPrimary)
                    Text(title)
                        .font(.lacticCaption)
                        .foregroundStyle(LacticColor.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .padding(isRow ? LacticSpacing.md : LacticSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LacticColor.surfaceElevated,
            in: RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                .strokeBorder(LacticColor.border, lineWidth: 1)
        }
    }
}

struct StudioActionFailureNotice: View {
    let failure: CoachActionFailure

    var body: some View {
        HStack(alignment: .top, spacing: LacticSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(LacticColor.danger)
                .frame(width: LacticSize.minimumHitTarget, height: LacticSize.minimumHitTarget)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                Text(title)
                    .font(.lacticHeadline)
                message
                    .font(.lacticBody)
                    .foregroundStyle(LacticColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(LacticSpacing.lg)
        .background(
            LacticColor.dangerSurface,
            in: RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                .strokeBorder(LacticColor.dangerBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch failure {
        case .offline: "wifi.slash"
        case .planIsFull, .rejected: "exclamationmark.triangle.fill"
        }
    }

    private var title: LocalizedStringKey {
        switch failure {
        case .offline: "You're offline"
        case .planIsFull: "Client limit reached"
        case .rejected: "That action was not completed"
        }
    }

    @ViewBuilder
    private var message: some View {
        switch failure {
        case .offline:
            Text("Check your connection and try again.")
        case .planIsFull:
            Text("No client slots are available. Client limits are managed on Lactic Web.")
        case .rejected(let message):
            // The API's wording is deliberately preserved exactly.
            Text(verbatim: message)
        }
    }
}

struct StudioInitialFailureView: View {
    let failure: CoachActionFailure
    /// A `Text` so it can be a translated key or data, like a client's name.
    let title: Text
    let retry: () -> Void

    var body: some View {
        VStack(spacing: LacticSpacing.lg) {
            StudioActionFailureNotice(failure: failure)
                .frame(maxWidth: 560)
            Button("Try again", action: retry)
                .lacticButton(.secondary)
                .frame(maxWidth: 240)
        }
        .padding(LacticSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LacticColor.surface)
        .navigationTitle(title)
    }
}

struct StudioEmptyCard<Action: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        VStack(spacing: LacticSpacing.md) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(LacticColor.textMuted)
                .accessibilityHidden(true)
            Text(title)
                .font(.lacticHeadline)
            Text(message)
                .font(.lacticBody)
                .foregroundStyle(LacticColor.textSecondary)
                .multilineTextAlignment(.center)
            action()
                .padding(.top, LacticSpacing.sm)
        }
        .padding(LacticSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(
            LacticColor.surfaceElevated,
            in: RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
                .strokeBorder(LacticColor.border, lineWidth: 1)
        }
    }
}

extension View {
    /// The elevated, bordered surface every Studio card sits on.
    func studioCard(radius: CGFloat = LacticRadius.control, padding: CGFloat = LacticSpacing.lg) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LacticColor.surfaceElevated,
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LacticColor.border, lineWidth: 1)
            }
    }
}
