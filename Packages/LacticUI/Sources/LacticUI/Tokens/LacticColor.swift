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
/// Light values started from `lactic-web`, which is stock Tailwind zinc plus a
/// few accents, so the two clients stay recognisably one product. They are not
/// copied blindly: the web's muted text is zinc-400 on near-white, which is
/// 2.46:1 and fails WCAG AA outright.
///
/// The dark values are designed rather than inverted. The web ships light-only
/// on purpose — a starter `prefers-color-scheme` block once left mid-workout
/// inputs unreadable — but on iOS a missing dark mode is conspicuous.
public enum LacticColor {
    // MARK: - Surfaces

    static let surfacePair = ColorPair(light: 0xFAFAFA, dark: 0x09090B)
    /// Cards and rows. Lighter than the page on dark, not whiter — and lifted
    /// from the obvious zinc-900 because at 1.12:1 a card had no visible edge
    /// at all under bright ambient light, which is the condition this app is
    /// actually used in.
    static let surfaceElevatedPair = ColorPair(light: 0xFFFFFF, dark: 0x1F1F25)
    static let surfacePressedPair = ColorPair(light: 0xF4F4F5, dark: 0x2A2A31)

    /// Stronger on dark than the light value's mirror image, for the same
    /// reason: a hairline that reads indoors disappears on a gym floor.
    static let borderPair = ColorPair(light: 0xE4E4E7, dark: 0x3F3F46)
    static let borderStrongPair = ColorPair(light: 0xD4D4D8, dark: 0x52525B)

    // MARK: - Text

    static let textPrimaryPair = ColorPair(light: 0x18181B, dark: 0xFAFAFA)
    static let textSecondaryPair = ColorPair(light: 0x52525B, dark: 0xA1A1AA)
    /// The weakest text that still carries meaning — an empty state's
    /// explanation, a field hint. Both values clear AA on the page *and* on a
    /// card, which is the stricter of the two: an elevated surface is lighter,
    /// so dark-mode text loses contrast there. The first dark value chosen
    /// passed on the page at 5.23 and failed on a card at 4.31, which is
    /// exactly the kind of gap that survives being eyeballed.
    ///
    /// The web's zinc-400 (#A1A1AA) fails outright at 2.46:1, which is why its
    /// empty states read as washed out.
    static let textMutedPair = ColorPair(light: 0x71717A, dark: 0x8A8A94)
    static let textOnAccentPair = ColorPair(light: 0xFAFAFA, dark: 0x18181B)

    // MARK: - Accent

    static let accentPair = ColorPair(light: 0x18181B, dark: 0xFAFAFA)
    static let accentPressedPair = ColorPair(light: 0x3F3F46, dark: 0xE4E4E7)

    /// Disabled controls are styled explicitly rather than by fading an enabled
    /// one. A blanket `.opacity(0.5)` inverted the hierarchy on dark: the accent
    /// is near-white there, so a half-faded primary button composited to
    /// 5.18:1 against the page while an *enabled* secondary button sat at
    /// 1.12:1 — the disabled control was the loudest thing on screen.
    /// Quieter than an *enabled* secondary button, measured rather than
    /// assumed: the first values chosen were still louder than it (dark 1.34
    /// vs 1.21 against the page), so the fill-level inversion survived the
    /// first fix even though the perceived one did not.
    static let surfaceDisabledPair = ColorPair(light: 0xF6F6F7, dark: 0x161619)
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
