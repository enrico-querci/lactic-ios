import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// Placeholder root. Replaced by the sign-in / shell split once `AuthService`
/// and the feature screens land.
struct RootView: View {
    var body: some View {
        VStack(spacing: LacticSpacing.lg) {
            Image(systemName: "dumbbell.fill")
                .font(.lacticDisplay)
                .foregroundStyle(LacticColor.brand)
                .accessibilityHidden(true)
            Text("Lactic Studio")
                .font(.lacticDisplay)
            Text("Coach")
                .font(.lacticEyebrow)
                .foregroundStyle(LacticColor.brand)
        }
        .foregroundStyle(LacticColor.textOnHero)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LacticColor.heroSurface)
    }
}

#Preview {
    RootView()
}
