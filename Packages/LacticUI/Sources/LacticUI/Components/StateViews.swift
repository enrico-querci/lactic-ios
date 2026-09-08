import SwiftUI

/// Shown while a screen's first load is in flight.
public struct LoadingView: View {
    private let label: String?

    public init(_ label: String? = nil) {
        self.label = label
    }

    public var body: some View {
        VStack(spacing: LacticSpacing.md) {
            ProgressView().controlSize(.large)
            if let label {
                Text(label)
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LacticSpacing.xxl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label ?? "Loading")
    }
}

/// Shown when a request succeeded and the answer is genuinely nothing.
public struct EmptyStateView: View {
    private let title: String
    private let message: String?
    private let systemImage: String?

    public init(title: String, message: String? = nil, systemImage: String? = nil) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    public var body: some View {
        VStack(spacing: LacticSpacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(LacticColor.textMuted)
                    .padding(.bottom, LacticSpacing.xs)
            }
            Text(title)
                .font(.lacticHeadline)
                .foregroundStyle(LacticColor.textSecondary)
            if let message {
                Text(message)
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LacticSpacing.xxl)
        .padding(.horizontal, LacticSpacing.lg)
    }
}

/// Shown when a load failed.
///
/// Always offers a retry, and never renders as an empty screen. The web's own
/// note on this is worth preserving: gym wifi fails routinely, and a blank page
/// is indistinguishable from "you have no programmes" — which is a much more
/// alarming thing for a client to conclude.
public struct ErrorStateView: View {
    private let message: String
    private let retry: (() -> Void)?

    public init(message: String, retry: (() -> Void)? = nil) {
        self.message = message
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: LacticSpacing.md) {
            Text(message)
                .font(.lacticBody)
                .foregroundStyle(LacticColor.danger)
                .multilineTextAlignment(.center)

            if let retry {
                Button("Try again", action: retry)
                    .lacticButton(.secondary, size: .small)
                    .fixedSize()
            }
        }
        .padding(LacticSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(LacticColor.dangerSurface)
        .clipShape(RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous)
                .strokeBorder(LacticColor.dangerBorder, lineWidth: 1)
        }
        // Deliberately no outer padding: a component that insets itself cannot
        // be aligned with its neighbours, and this one sits next to banners and
        // list rows that set their own margins.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// A failed *action*, as opposed to a failed load — the screen still has its
/// content, so this sits above it rather than replacing it.
///
/// Dismissible and non-blocking, but deliberately loud: a set that silently
/// failed to save is one the trainee will not think to re-enter.
public struct ErrorBanner: View {
    private let message: String
    private let dismiss: () -> Void

    public init(message: String, dismiss: @escaping () -> Void) {
        self.message = message
        self.dismiss = dismiss
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: LacticSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(LacticColor.danger)
                .accessibilityHidden(true)

            Text(message)
                .font(.lacticCaption)
                .foregroundStyle(LacticColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LacticColor.textSecondary)
                    .frame(width: LacticSize.minimumHitTarget, height: LacticSize.minimumHitTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, LacticSpacing.md)
        .background(LacticColor.dangerSurface)
        .clipShape(RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                .strokeBorder(LacticColor.dangerBorder, lineWidth: 1)
        }
    }
}

#Preview("States") {
    ScrollView {
        VStack(spacing: LacticSpacing.xl) {
            LoadingView("Loading your programme")
            EmptyStateView(
                title: "No programmes yet",
                message: "Your coach has not assigned anything.",
                systemImage: "list.bullet.rectangle"
            )
            ErrorStateView(message: "Could not connect to the server.") {}
            ErrorBanner(message: "That set could not be saved.") {}
                .padding(.horizontal, LacticSpacing.lg)
        }
    }
    .background(LacticColor.surface)
}
