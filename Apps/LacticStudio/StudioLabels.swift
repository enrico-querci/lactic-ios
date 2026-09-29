import Foundation
import LacticCore
import LacticKit
import LacticUI

// Display names for API vocabulary. The raw values are English identifiers;
// only these labels are translated, in Studio's string catalog.

extension AssignmentStatus {
    var label: String {
        switch self {
        case .active: String(localized: "Active")
        case .paused: String(localized: "Paused")
        case .completed: String(localized: "Completed")
        }
    }

    var tone: StatusBadge.Tone {
        switch self {
        case .active: .positive
        case .paused: .caution
        case .completed: .neutral
        }
    }

    var systemImage: String {
        switch self {
        case .active: "play.circle"
        case .paused: "pause.circle"
        case .completed: "checkmark.circle"
        }
    }
}

extension SubscriptionPlan {
    var label: String {
        switch self {
        case .free: String(localized: "Free")
        case .pro: "Pro"
        case .proPlus: "Pro+"
        case .unlimited: String(localized: "Unlimited")
        case .founding: "Founding"
        case .other(let raw): raw.capitalized
        }
    }
}

extension CalendarDate {
    /// Formatted in the app's language, falling back to `YYYY-MM-DD` if the
    /// calendar cannot place it.
    func formatted(locale: AppLocale) -> String {
        date().map { Formatters.date($0, locale: locale) } ?? description
    }
}
