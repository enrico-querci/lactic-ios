import SwiftUI

public struct LacticButtonStyle: ButtonStyle {
    public enum Prominence: Sendable {
        /// The one action a screen is asking for.
        case primary
        /// Everything else.
        case secondary
        /// Irreversible: deleting an account, discarding a session.
        case danger
    }

    public enum Size: Sendable {
        case small
        case regular

        var verticalPadding: CGFloat {
            switch self {
            case .small: LacticSpacing.sm
            case .regular: LacticSpacing.md
            }
        }

        var font: Font {
            switch self {
            case .small: .footnote.weight(.medium)
            case .regular: .body.weight(.semibold)
            }
        }
    }

    private let prominence: Prominence
    private let size: Size
    private let isEnabled: Bool

    public init(prominence: Prominence = .primary, size: Size = .regular, isEnabled: Bool = true) {
        self.prominence = prominence
        self.size = size
        self.isEnabled = isEnabled
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(foreground)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, LacticSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: LacticSize.minimumHitTarget)
            .background(background(pressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous))
            .overlay {
                if prominence == .secondary || !isEnabled {
                    RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous)
                        // Always `border`: the disabled variant previously used
                        // `surfacePressed`, which in light mode is the same
                        // colour as the disabled fill, so the overlay rendered
                        // an invisible stroke and the button lost its shape.
                        .strokeBorder(LacticColor.border, lineWidth: 1)
                }
            }

            // Only the press state animates. Growing or shrinking a button
            // under a thumb mid-workout reads as a mis-tap.
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        guard isEnabled else { return LacticColor.textDisabled }
        switch prominence {
        case .primary: return LacticColor.textOnAccent
        case .secondary: return LacticColor.textPrimary
        case .danger: return .white
        }
    }

    /// Disabled is its own pair of tokens rather than a faded enabled one.
    /// Fading composites the fill toward the page, and on dark — where the
    /// accent is near-white — that lands a disabled primary button at 5.18:1
    /// against the page while an enabled secondary sits at 1.12:1, making the
    /// unavailable control the loudest thing on screen.
    private func background(pressed: Bool) -> Color {
        guard isEnabled else { return LacticColor.surfaceDisabled }
        switch prominence {
        case .primary: return pressed ? LacticColor.accentPressed : LacticColor.accent
        case .secondary: return pressed ? LacticColor.surfacePressed : LacticColor.surfaceElevated
        case .danger: return LacticColor.danger.opacity(pressed ? 0.85 : 1)
        }
    }
}

public extension View {
    func lacticButton(
        _ prominence: LacticButtonStyle.Prominence = .primary,
        size: LacticButtonStyle.Size = .regular,
        isEnabled: Bool = true
    ) -> some View {
        buttonStyle(LacticButtonStyle(prominence: prominence, size: size, isEnabled: isEnabled))
            .disabled(!isEnabled)
    }
}

#Preview("Buttons") {
    VStack(spacing: LacticSpacing.md) {
        Button("Start workout") {}.lacticButton()
        Button("Add set") {}.lacticButton(.secondary)
        Button("Delete account") {}.lacticButton(.danger)
        Button("Disabled") {}.lacticButton(isEnabled: false)
        Button("Small") {}.lacticButton(.secondary, size: .small)
    }
    .padding()
    .background(LacticColor.surface)
}
