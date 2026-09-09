import SwiftUI

/// Spacing, radii and sizes, so screens agree without repeating numbers.
public enum LacticSpacing {
    /// 4 pt. Between a label and the value it describes.
    public static let xs: CGFloat = 4
    /// 8 pt. Within a component.
    public static let sm: CGFloat = 8
    /// 12 pt. Between rows in a list.
    public static let md: CGFloat = 12
    /// 16 pt. Standard content spacing.
    public static let lg: CGFloat = 16
    /// 24 pt. Between sections.
    public static let xl: CGFloat = 24
    /// 32 pt. Around an empty or error state.
    public static let xxl: CGFloat = 32
}

public enum LacticRadius {
    /// 14 pt. Comfortable, substantial controls.
    public static let control: CGFloat = 14
    /// 20 pt. Soft card edges against the graphite and chalk surfaces.
    public static let card: CGFloat = 20
    /// Chips and badges, matching `rounded-full`.
    public static let pill: CGFloat = 999
}

public enum LacticSize {
    /// Apple's minimum comfortable hit target. Every control that gets tapped
    /// mid-set honours this — those taps happen with chalky hands, in a hurry,
    /// often one-handed.
    public static let minimumHitTarget: CGFloat = 44
}
