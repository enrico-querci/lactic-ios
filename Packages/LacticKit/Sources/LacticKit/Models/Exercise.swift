import Foundation

/// A muscle as the API names it. `key` is stable and never localized — it is
/// what filters are keyed on — while `name` is translated.
public struct MuscleRef: Codable, Hashable, Sendable {
    public let key: String
    public let name: String
    public let region: String?
}

/// Equipment, and also a *secondary* muscle: the API omits `region` from
/// `secondary_muscles` even though `primary_muscle` carries it, so the two
/// muscle shapes are genuinely different types on the wire.
public struct TaxonomyRef: Codable, Hashable, Sendable {
    public let key: String
    public let name: String
}

/// `ExerciseBlueprint`'s default view: what index endpoints return and what is
/// nested inside every `workout_exercise`.
public struct Exercise: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    /// Localized by the API from `Accept-Language`, falling back to English.
    public let name: String
    public let isCustom: Bool
    public let category: String?
    public let difficulty: String?
    public let mechanic: String?
    public let force: String?
    public let prescriptionType: String
    public let active: Bool
    public let assignable: Bool
    public let primaryMuscle: MuscleRef?
    public let equipment: [TaxonomyRef]
    public let hasAnimation: Bool
    /// A path rooted at `/api/v1`, not an absolute URL, and it requires the
    /// `Authorization` header. Resolve it with `APIConfiguration.animationURL`.
    public let animationPath: String?

    // Pre-catalog columns. Still NOT NULL server-side and still served, so
    // they stay part of the contract until the catalog work retires them.
    public let muscleGroup: String
    public let videoURL: String?
    public let thumbnailURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category, difficulty, mechanic, force, active, assignable, equipment
        case isCustom = "is_custom"
        case prescriptionType = "prescription_type"
        case primaryMuscle = "primary_muscle"
        case hasAnimation = "has_animation"
        case animationPath = "animation_url"
        case muscleGroup = "muscle_group"
        case videoURL = "video_url"
        case thumbnailURL = "thumbnail_url"
    }
}

/// `ExerciseBlueprint`'s `:detail` view — a strict superset of the default one.
///
/// The extra keys are **absent** from list rows rather than null, so they
/// cannot simply be optional properties on `Exercise`: decoding a list row into
/// a detail type has to fail, and decoding a detail row must not silently drop
/// them.
public struct ExerciseDetail: Decodable, Hashable, Sendable, Identifiable {
    public let exercise: Exercise
    public let description: String?
    public let instructions: [String]
    /// The locale actually served, which differs from the one requested when
    /// the API falls back. `nil` when the exercise has no translations at all.
    public let locale: String?
    public let secondaryMuscles: [TaxonomyRef]

    public var id: Int {
        exercise.id
    }

    public var name: String {
        exercise.name
    }

    public var hasAnimation: Bool {
        exercise.hasAnimation
    }

    public var animationPath: String? {
        exercise.animationPath
    }

    public var primaryMuscle: MuscleRef? {
        exercise.primaryMuscle
    }

    public var equipment: [TaxonomyRef] {
        exercise.equipment
    }

    enum CodingKeys: String, CodingKey {
        case description, instructions, locale
        case secondaryMuscles = "secondary_muscles"
    }

    public init(from decoder: any Decoder) throws {
        exercise = try Exercise(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        instructions = try container.decode([String].self, forKey: .instructions)
        locale = try container.decodeIfPresent(String.self, forKey: .locale)
        secondaryMuscles = try container.decode([TaxonomyRef].self, forKey: .secondaryMuscles)
    }
}

/// `GET /coach/exercise_taxonomy`. Coach-only — there is no client equivalent,
/// so the client app cannot build filter pickers from the server's vocabulary.
public struct ExerciseTaxonomy: Codable, Hashable, Sendable {
    public let muscles: [MuscleRef]
    public let equipment: [TaxonomyRef]
    public let categories: [String]
    public let difficulties: [String]
}
