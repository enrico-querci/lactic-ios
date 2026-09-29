import AuthenticationServices
import SwiftUI

/// Apple's Sign in with Apple button, sized to sit beside `lacticButton()`.
///
/// App Review expects Apple's own button, or a replica that follows its
/// guidelines to the letter, so this wraps `SignInWithAppleButton` rather than
/// restyling it. Only the frame and the corner radius are Lactic's.
public struct LacticAppleSignInButton: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Matches a regular `lacticButton()`: a semibold body line plus its
    /// vertical padding. Scaled so the pair grows together with Dynamic Type,
    /// but capped, because Apple's label scales with the height and would
    /// otherwise dwarf everything beside it at accessibility sizes.
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 48

    private let isEnabled: Bool
    private let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    private let onCompletion: (Result<ASAuthorization, any Error>) -> Void

    public init(
        isEnabled: Bool = true,
        onRequest: @escaping (ASAuthorizationAppleIDRequest) -> Void,
        onCompletion: @escaping (Result<ASAuthorization, any Error>) -> Void
    ) {
        self.isEnabled = isEnabled
        self.onRequest = onRequest
        self.onCompletion = onCompletion
    }

    public var body: some View {
        SignInWithAppleButton(.continue, onRequest: onRequest, onCompletion: onCompletion)
            // Black on chalk and white on graphite is Apple's own guidance, and
            // happens to match the primary button's weight in both appearances.
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            // The style is fixed when the underlying control is created, so a
            // live switch to dark mode would leave a black button on graphite.
            .id(colorScheme)
            .frame(maxWidth: .infinity)
            .frame(height: min(height, 64))
            .clipShape(RoundedRectangle(cornerRadius: LacticRadius.control, style: .continuous))
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.4)
    }
}

#Preview("Apple sign-in") {
    VStack(spacing: LacticSpacing.md) {
        LacticAppleSignInButton(onRequest: { _ in }, onCompletion: { _ in })
        Button("Continue with Google") {}.lacticButton()
        LacticAppleSignInButton(isEnabled: false, onRequest: { _ in }, onCompletion: { _ in })
    }
    .padding()
}
