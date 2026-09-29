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

extension CustomMuscleGroup {
    var label: String {
        switch self {
        case .chest: String(localized: "Chest")
        case .back: String(localized: "Back")
        case .shoulders: String(localized: "Shoulders")
        case .quadriceps: String(localized: "Quadriceps")
        case .hamstrings: String(localized: "Hamstrings")
        case .glutes: String(localized: "Glutes")
        case .biceps: String(localized: "Biceps")
        case .triceps: String(localized: "Triceps")
        case .core: String(localized: "Core")
        case .calves: String(localized: "Calves")
        case .forearms: String(localized: "Forearms")
        case .traps: String(localized: "Traps")
        case .fullBody: String(localized: "Full body")
        }
    }
}

extension Exercise {
    /// The catalog's localized primary muscle, or — for a coach's own
    /// exercise, which never gets one — the legacy muscle group, translated
    /// through the same vocabulary the create form offers.
    var muscleLabel: String {
        if let primaryMuscle {
            return primaryMuscle.name
        }
        return CustomMuscleGroup(rawValue: muscleGroup)?.label ?? muscleGroup
    }
}

extension WorkoutExercise {
    /// `3 × 10 · 90 s rest · RIR 2 · 60 kg`, leaving out what the coach did
    /// not prescribe.
    func prescriptionSummary(locale: AppLocale) -> String {
        var parts = ["\(sets) × \(reps)", String(localized: "\(effectiveRestSeconds) s rest")]
        if let rir {
            parts.append(String(localized: "RIR \(rir)"))
        }
        if let weight {
            parts.append("\(Formatters.weight(weight, locale: locale)) kg")
        }
        return parts.joined(separator: " · ")
    }
}
