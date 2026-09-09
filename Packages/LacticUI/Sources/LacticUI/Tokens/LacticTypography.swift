import SwiftUI

/// Text styles.
///
/// Everything is built on the system text styles rather than fixed point sizes,
/// so Dynamic Type works by default instead of being retrofitted.
public extension Font {
    /// Brand moments and welcoming headlines. System SF, with Dynamic Type.
    static let lacticDisplay = Font.system(.largeTitle, design: .default, weight: .heavy)
    /// Screen titles.
    static let lacticTitle = Font.title.weight(.bold)
    /// Section headings and card titles.
    static let lacticHeadline = Font.headline.weight(.semibold)
    static let lacticEyebrow = Font.caption.weight(.bold)
    static let lacticBody = Font.body
    static let lacticCaption = Font.caption

    /// Numbers that change in place — a running rest timer, a weight being
    /// edited. Monospaced digits stop the layout jittering as digits change
    /// width, which is otherwise very visible on a one-second tick.
    static let lacticNumeric = Font.body.monospacedDigit()
    static let lacticTimer = Font.largeTitle.weight(.bold).monospacedDigit()
}
