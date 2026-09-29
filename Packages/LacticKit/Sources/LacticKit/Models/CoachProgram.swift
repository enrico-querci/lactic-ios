import Foundation

/// `GET /coach/programs/:id` — `ProgramBlueprint`'s `:extended` view.
///
/// Not `ProgramDetail`: that is the client's view, which merges in the
/// `assignment_id` of *their* assignment. A coach's program belongs to no one
/// assignment, so the key is absent here and decoding `ProgramDetail` would
/// fail.
///
/// Mutable because the program builder applies each change's own response
/// locally instead of re-fetching the whole program after every edit.
public struct CoachProgram: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public var name: String
    public var description: String?
    public let createdAt: Date
    public var weeks: [Week]

    enum CodingKeys: String, CodingKey {
        case id, name, description, weeks
        case createdAt = "created_at"
    }

    /// Weeks in programme order.
    public var orderedWeeks: [Week] {
        weeks.sorted { $0.position < $1.position }
    }
}

/// A week as `POST /coach/programs/:id/weeks` returns it: `WeekBlueprint`'s
/// default view, which has no `workouts` key at all — so it cannot decode as
/// `Week`.
public struct WeekSummary: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let position: Int
}

extension Week {
    init(summary: WeekSummary, workouts: [Workout] = []) {
        self.init(id: summary.id, position: summary.position, workouts: workouts)
    }

    func replacingWorkouts(_ transform: ([Workout]) -> [Workout]) -> Week {
        Week(id: id, position: position, workouts: transform(workouts))
    }
}

/// The muscle-group vocabulary a coach picks from when creating a custom
/// exercise.
///
/// The raw value is posted verbatim into a free-form column and must stay
/// English: the API's glossary localizes these same words when they come
/// back as `volume_sets` keys, so a translated value would never match. Only
/// the label a screen shows is translated, and that belongs to the app.
public enum CustomMuscleGroup: String, CaseIterable, Sendable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case quadriceps = "Quadriceps"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case core = "Core"
    case calves = "Calves"
    case forearms = "Forearms"
    case traps = "Traps"
    case fullBody = "Full Body"

    public var id: String {
        rawValue
    }
}
