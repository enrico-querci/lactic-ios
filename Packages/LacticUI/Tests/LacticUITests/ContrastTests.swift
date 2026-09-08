import Foundation
import Testing
@testable import LacticUI

/// WCAG 2.1 relative luminance and contrast, computed from the token values.
private enum WCAG {
    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ raw: UInt32) -> Double {
            let value = Double(raw) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((hex >> 16) & 0xFF)
            + 0.7152 * channel((hex >> 8) & 0xFF)
            + 0.0722 * channel(hex & 0xFF)
    }

    static func ratio(_ foreground: UInt32, _ background: UInt32) -> Double {
        let (first, second) = (luminance(foreground), luminance(background))
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    /// AA for body text.
    static let normalText = 4.5
    /// AA for text at 18pt+ or 14pt+ bold, and for UI component boundaries.
    static let largeText = 3.0
}

/// Guards the palette's accessibility.
///
/// These exist because the light values were ported from `lactic-web`, and one
/// of them — zinc-400 for muted text — fails AA at 2.46:1. It shipped there
/// unnoticed because nothing checked. Eyeballing a palette does not catch a
/// 2.46, especially on a good display in a dark room, and this app is used on a
/// gym floor under glare.
@Suite("Palette contrast")
struct ContrastTests {
    private static let textRoles: [(String, ColorPair)] = [
        ("textPrimary", LacticColor.textPrimaryPair),
        ("textSecondary", LacticColor.textSecondaryPair),
        ("textMuted", LacticColor.textMutedPair),
    ]

    @Test func everyTextRoleClearsAAOnThePage() {
        for (name, pair) in Self.textRoles {
            let light = WCAG.ratio(pair.light, LacticColor.surfacePair.light)
            let dark = WCAG.ratio(pair.dark, LacticColor.surfacePair.dark)
            #expect(light >= WCAG.normalText, "\(name) light is \(light) on the page")
            #expect(dark >= WCAG.normalText, "\(name) dark is \(dark) on the page")
        }
    }

    @Test func everyTextRoleClearsAAOnACard() {
        for (name, pair) in Self.textRoles {
            let light = WCAG.ratio(pair.light, LacticColor.surfaceElevatedPair.light)
            let dark = WCAG.ratio(pair.dark, LacticColor.surfaceElevatedPair.dark)
            #expect(light >= WCAG.normalText, "\(name) light is \(light) on a card")
            #expect(dark >= WCAG.normalText, "\(name) dark is \(dark) on a card")
        }
    }

    /// The hierarchy has to survive the contrast fix: making muted text legible
    /// is pointless if it ends up as loud as secondary.
    @Test func theTextHierarchyIsOrdered() {
        for (mode, surface, primary, secondary, muted) in [
            (
                "light",
                LacticColor.surfacePair.light,
                LacticColor.textPrimaryPair.light,
                LacticColor.textSecondaryPair.light,
                LacticColor.textMutedPair.light
            ),
            (
                "dark",
                LacticColor.surfacePair.dark,
                LacticColor.textPrimaryPair.dark,
                LacticColor.textSecondaryPair.dark,
                LacticColor.textMutedPair.dark
            ),
        ] {
            let ordered = WCAG.ratio(primary, surface) > WCAG.ratio(secondary, surface)
                && WCAG.ratio(secondary, surface) > WCAG.ratio(muted, surface)
            #expect(ordered, "\(mode): primary > secondary > muted must hold")
        }
    }

    @Test func labelsOnFilledButtonsAreReadable() {
        let onAccent = LacticColor.textOnAccentPair
        let accent = LacticColor.accentPair
        #expect(WCAG.ratio(onAccent.light, accent.light) >= WCAG.normalText)
        #expect(WCAG.ratio(onAccent.dark, accent.dark) >= WCAG.normalText)
        #expect(WCAG.ratio(0xFFFFFF, LacticColor.dangerPair.light) >= WCAG.largeText)
    }

    /// The bug the screenshots caught: with a blanket `.opacity(0.5)`, a
    /// disabled primary button on dark composited to 5.18:1 against the page
    /// while an *enabled* secondary sat at 1.12:1 — the unavailable control was
    /// the loudest thing on screen.
    ///
    /// This compares disabled against the **enabled secondary** directly.
    /// An earlier version of this test compared each of them against the accent
    /// instead and never against each other, so it passed while a fill-level
    /// inversion was still present — a test asserting something weaker than its
    /// own name claims is worse than no test, because it is read as coverage.
    @Test func aDisabledButtonIsQuieterThanAnEnabledOne() {
        for (mode, page, disabled, enabledSecondary, accent) in [
            (
                "light",
                LacticColor.surfacePair.light,
                LacticColor.surfaceDisabledPair.light,
                LacticColor.surfaceElevatedPair.light,
                LacticColor.accentPair.light
            ),
            (
                "dark",
                LacticColor.surfacePair.dark,
                LacticColor.surfaceDisabledPair.dark,
                LacticColor.surfaceElevatedPair.dark,
                LacticColor.accentPair.dark
            ),
        ] {
            // Prominence is how far a fill stands off the page it sits on.
            let disabledFill = WCAG.ratio(disabled, page)
            let secondaryFill = WCAG.ratio(enabledSecondary, page)
            let accentFill = WCAG.ratio(accent, page)

            #expect(
                disabledFill < secondaryFill,
                "\(mode): disabled fill \(disabledFill) must be quieter than enabled secondary \(secondaryFill)"
            )
            #expect(
                disabledFill < accentFill,
                "\(mode): disabled fill \(disabledFill) must be quieter than the primary accent \(accentFill)"
            )
        }
    }

    /// The label carries most of the signal about whether a control is
    /// available, so it has to weaken too — not just the fill.
    @Test func aDisabledLabelIsQuieterThanAnEnabledOne() {
        for (mode, disabledLabel, disabledFill, enabledLabel, enabledFill) in [
            (
                "light",
                LacticColor.textDisabledPair.light, LacticColor.surfaceDisabledPair.light,
                LacticColor.textPrimaryPair.light, LacticColor.surfaceElevatedPair.light
            ),
            (
                "dark",
                LacticColor.textDisabledPair.dark, LacticColor.surfaceDisabledPair.dark,
                LacticColor.textPrimaryPair.dark, LacticColor.surfaceElevatedPair.dark
            ),
        ] {
            let disabled = WCAG.ratio(disabledLabel, disabledFill)
            let enabled = WCAG.ratio(enabledLabel, enabledFill)
            #expect(disabled < enabled, "\(mode): disabled label \(disabled) vs enabled \(enabled)")
        }
    }

    /// A border that matches the fill it outlines renders nothing. The disabled
    /// button shipped exactly that for one revision: `surfacePressed` on a
    /// `surfaceDisabled` fill is the *same colour* in light mode, so the
    /// overlay drew an invisible stroke and the control lost its shape.
    @Test func everyBorderIsVisibleAgainstTheSurfaceItOutlines() {
        for (name, border, fill) in [
            ("card", LacticColor.borderPair, LacticColor.surfaceElevatedPair),
            ("disabled button", LacticColor.borderPair, LacticColor.surfaceDisabledPair),
            ("position badge", LacticColor.borderStrongPair, LacticColor.surfacePressedPair),
        ] {
            let light = WCAG.ratio(border.light, fill.light)
            let dark = WCAG.ratio(border.dark, fill.dark)
            #expect(light > 1.1, "\(name) border is invisible in light (\(light))")
            #expect(dark > 1.1, "\(name) border is invisible in dark (\(dark))")
        }
    }

    /// Status colours have to stay legible against their own tinted surfaces,
    /// which is where a light-mode value goes muddy if reused on dark.
    @Test func statusTextIsLegibleOnItsOwnSurface() {
        for (name, foreground, background) in [
            ("danger", LacticColor.dangerPair, LacticColor.dangerSurfacePair),
            ("success", LacticColor.successPair, LacticColor.successSurfacePair),
            ("warning", LacticColor.warningPair, LacticColor.warningSurfacePair),
            ("info", LacticColor.infoPair, LacticColor.infoSurfacePair),
        ] {
            let light = WCAG.ratio(foreground.light, background.light)
            let dark = WCAG.ratio(foreground.dark, background.dark)
            #expect(light >= WCAG.largeText, "\(name) light badge is \(light)")
            #expect(dark >= WCAG.largeText, "\(name) dark badge is \(dark)")
        }
    }

    /// A card has to be distinguishable from the page it sits on. Dark makes
    /// this hard — the values are close by nature — so this is a floor, not a
    /// target, and the reason `surfaceElevated` was lifted off zinc-900.
    @Test func cardsAreDistinguishableFromThePage() {
        #expect(WCAG.ratio(LacticColor.surfaceElevatedPair.dark, LacticColor.surfacePair.dark) > 1.15)
        #expect(WCAG.ratio(LacticColor.borderPair.dark, LacticColor.surfaceElevatedPair.dark) > 1.3)
    }
}
