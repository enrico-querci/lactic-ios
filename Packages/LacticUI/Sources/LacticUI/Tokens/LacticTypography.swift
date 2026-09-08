import SwiftUI

/// Text styles.
///
/// Everything is built on the system text styles rather than fixed point sizes,
/// so Dynamic Type works by default instead of being retrofitted.
public extension Font {
    /// Screen titles.
    static let lacticTitle = Font.title2.weight(.bold)
    /// Section headings and card titles.
    static let lacticHeadline = Font.headline
    static let lacticBody = Font.body
    static let lacticCaption = Font.caption

    /// Numbers that change in place — a running rest timer, a weight being
    /// edited. Monospaced digits stop the layout jittering as digits change
    /// width, which is otherwise very visible on a one-second tick.
    static let lacticNumeric = Font.body.monospacedDigit()
    static let lacticTimer = Font.title.weight(.semibold).monospacedDigit()
}
