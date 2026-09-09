import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

/// A light/dark pair of sRGB values.
///
/// The raw values stay reachable inside the module so the contrast tests can
/// assert on them. A palette whose accessibility is only ever checked by eye
/// drifts the first time someone tweaks a shade.
struct ColorPair: Sendable {
    let light: UInt32
    let dark: UInt32

    var color: Color {
        #if canImport(UIKit)
            return Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(rgbHex: dark)
                    : UIColor(rgbHex: light)
            })
        #else
            // The package builds for macOS only so `swift test` runs on the
            // host; nothing ships there, so the light value is enough.
            return Color(rgbHex: light)
        #endif
    }
}

/// The palette, as semantic roles rather than raw colours.
///
/// Chalk and graphite surfaces with an electric lime identity. Interactive
/// green deepens in light mode so small labels remain readable.
public enum LacticColor {
    // MARK: - Surfaces

    static let surfacePair = ColorPair(light: 0xF5F6F0, dark: 0x10130F)
    /// Lifted surfaces keep cards distinct in dark mode under gym lighting.
    static let surfaceElevatedPair = ColorPair(light: 0xFFFFFF, dark: 0x22271F)
    static let surfacePressedPair = ColorPair(light: 0xEAEDE3, dark: 0x30372B)

    /// Stronger on dark than the light value's mirror image, for the same
    /// reason: a hairline that reads indoors disappears on a gym floor.
    static let borderPair = ColorPair(light: 0xDCE1D5, dark: 0x444D3E)
    static let borderStrongPair = ColorPair(light: 0xBAC3B1, dark: 0x65725B)

    // MARK: - Text

    static let textPrimaryPair = ColorPair(light: 0x192118, dark: 0xF4F6EE)
    static let textSecondaryPair = ColorPair(light: 0x505B49, dark: 0xB5BEAB)
    /// Hints and supporting copy still clear AA on both pages and cards.
    static let textMutedPair = ColorPair(light: 0x697360, dark: 0x99A38F)
    static let textOnAccentPair = ColorPair(light: 0xFFFFFF, dark: 0x192118)

    // MARK: - Accent

    static let accentPair = ColorPair(light: 0x466B12, dark: 0xCCF36B)
    static let accentPressedPair = ColorPair(light: 0x36530E, dark: 0xB7DE56)

    /// Explicit disabled colors keep unavailable actions quieter than both
    /// enabled button styles, without compositing the bright accent.
    static let surfaceDisabledPair = ColorPair(light: 0xF3F4EE, dark: 0x191D16)
    static let textDisabledPair = ColorPair(light: 0xA1A1AA, dark: 0x71717A)

    // MARK: - Status

    static let dangerPair = ColorPair(light: 0xDC2626, dark: 0xEF4444)
    static let dangerSurfacePair = ColorPair(light: 0xFEF2F2, dark: 0x2A1315)
    static let dangerBorderPair = ColorPair(light: 0xFECACA, dark: 0x7F1D1D)

    static let successPair = ColorPair(light: 0x15803D, dark: 0x4ADE80)
    static let successSurfacePair = ColorPair(light: 0xDCFCE7, dark: 0x14261B)

    static let warningPair = ColorPair(light: 0xA16207, dark: 0xFACC15)
    static let warningSurfacePair = ColorPair(light: 0xFEF9C3, dark: 0x2A2210)

    static let infoPair = ColorPair(light: 0x1D4ED8, dark: 0x60A5FA)
    static let infoSurfacePair = ColorPair(light: 0xDBEAFE, dark: 0x11203F)

    /// Identity colors for hero panels; always pair hero text with heroSurface.
    public static let brand = Color(rgbHex: 0xCCF36B)
    public static let heroSurface = Color(rgbHex: 0x192118)
    public static let textOnHero = Color(rgbHex: 0xF4F6EE)

    // MARK: - Public surface

    public static let surface = surfacePair.color
    public static let surfaceElevated = surfaceElevatedPair.color
    public static let surfacePressed = surfacePressedPair.color
    public static let border = borderPair.color
    public static let borderStrong = borderStrongPair.color
    public static let textPrimary = textPrimaryPair.color
    public static let textSecondary = textSecondaryPair.color
    public static let textMuted = textMutedPair.color
    public static let textOnAccent = textOnAccentPair.color
    public static let accent = accentPair.color
    public static let accentPressed = accentPressedPair.color
    public static let surfaceDisabled = surfaceDisabledPair.color
    public static let textDisabled = textDisabledPair.color
    public static let danger = dangerPair.color
    public static let dangerSurface = dangerSurfacePair.color
    public static let dangerBorder = dangerBorderPair.color
    public static let success = successPair.color
    public static let successSurface = successSurfacePair.color
    public static let warning = warningPair.color
    public static let warningSurface = warningSurfacePair.color
    public static let info = infoPair.color
    public static let infoSurface = infoSurfacePair.color
}

extension Color {
    init(rgbHex: UInt32) {
        self.init(
            .sRGB,
            red: Double((rgbHex >> 16) & 0xFF) / 255,
            green: Double((rgbHex >> 8) & 0xFF) / 255,
            blue: Double(rgbHex & 0xFF) / 255,
            opacity: 1
        )
    }
}

#if canImport(UIKit)
    extension UIColor {
        convenience init(rgbHex: UInt32) {
            self.init(
                red: CGFloat((rgbHex >> 16) & 0xFF) / 255,
                green: CGFloat((rgbHex >> 8) & 0xFF) / 255,
                blue: CGFloat(rgbHex & 0xFF) / 255,
                alpha: 1
            )
        }
    }
#endif
