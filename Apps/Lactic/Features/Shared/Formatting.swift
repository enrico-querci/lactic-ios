import LacticCore
import LacticKit
import LacticUI
import SwiftUI

/// Presentation helpers shared across the client screens.
enum ClientFormat {
    /// Assignment status as a badge tone, matching the web's colour choices.
    static func tone(for status: AssignmentStatus) -> StatusBadgeTone {
        switch status {
        case .active: .positive
        case .paused: .caution
        case .completed: .neutral
        }
    }

    static func title(for status: AssignmentStatus) -> String {
        switch status {
        case .active: String(localized: "Active")
        case .paused: String(localized: "Paused")
        case .completed: String(localized: "Completed")
        }
    }

    /// A session's elapsed time, or nil while it is still running.
    static func duration(of session: WorkoutSession) -> String? {
        guard let started = session.startedAt, let completed = session.completedAt else { return nil }
        return Formatters.duration(from: started, to: completed)
    }

    /// `volume_sets` sorted for display. The keys are localized display names
    /// the server produced, so they sort by name rather than by any identifier.
    static func orderedVolume(_ volumeSets: [String: Int]) -> [(muscleGroup: String, sets: Int)] {
        volumeSets
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
            .map { (muscleGroup: $0.key, sets: $0.value) }
    }
}

/// Mirrors `StatusBadge.Tone` so screens do not each reimplement the mapping.
typealias StatusBadgeTone = StatusBadge.Tone
