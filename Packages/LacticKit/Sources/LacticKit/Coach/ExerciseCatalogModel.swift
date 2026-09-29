import Foundation
import Observation

/// What the catalog is narrowed to. Taxonomy values are the API's stable
/// keys, never the translated names, so a filter survives a language switch.
public struct ExerciseFilter: Equatable, Sendable {
    public enum Ownership: String, CaseIterable, Sendable {
        case all
        /// The shared catalog only.
        case catalog
        /// Only exercises this coach created.
        case mine
    }

    public var search = ""
    public var muscle: String?
    public var equipment: String?
    public var category: String?
    public var difficulty: String?
    public var ownership = Ownership.all

    public init() {}

    public var isActive: Bool {
        self != ExerciseFilter()
    }
}

/// The exercise catalog: well over a thousand entries, so paged, filtered
/// server-side, and appended as the list scrolls.
///
/// Also the exercise picker's model. The server only lists what may actually
/// be put into a workout — active and assignable — so the picker cannot offer
/// something the builder would then refuse.
@MainActor
@Observable
public final class ExerciseCatalogModel: CoachActionPerforming {
    public var filter = ExerciseFilter()

    public private(set) var exercises: [Exercise] = []
    public private(set) var totalCount = 0
    /// Best effort: it only feeds the filter pickers, so a failure degrades
    /// filtering rather than hiding the list.
    public private(set) var taxonomy: ExerciseTaxonomy?
    public private(set) var hasLoaded = false
    public private(set) var isLoading = false
    public private(set) var isLoadingMore = false
    public internal(set) var isSubmitting = false
    public internal(set) var failure: CoachActionFailure?

    @ObservationIgnored private let client: APIClient
    @ObservationIgnored private let perPage: Int
    @ObservationIgnored private var page = 0
    @ObservationIgnored private var totalPages = 1
    /// Bumped by every fresh load, so a slow response for a filter the coach
    /// has already moved past is dropped instead of overwriting newer results.
    @ObservationIgnored private var generation = 0

    public init(client: APIClient, perPage: Int = 25) {
        self.client = client
        self.perPage = perPage
    }

    public var hasMore: Bool {
        page < totalPages
    }

    /// Loads the taxonomy once and the first page for the current filter.
    public func load() async {
        if taxonomy == nil {
            taxonomy = try? await client.send(CoachAPI.exerciseTaxonomy)
        }
        await reload()
    }

    /// Starts over from page one — call it after changing `filter`.
    public func reload() async {
        generation += 1
        let current = generation
        isLoading = true
        defer {
            if current == generation {
                isLoading = false
            }
        }
        do {
            let result = try await fetch(page: 1)
            guard current == generation else { return }
            exercises = result.items
            apply(result)
            hasLoaded = true
            failure = nil
        } catch {
            guard current == generation else { return }
            failure = CoachActionFailure(error)
        }
    }

    /// Appends the next page. Safe to call repeatedly from a scrolling list:
    /// it does nothing while a page is already on its way or none is left.
    public func loadMore() async {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        let current = generation
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await fetch(page: page + 1)
            guard current == generation else { return }
            // A row can shift pages between requests; never show it twice.
            let seen = Set(exercises.map(\.id))
            exercises += result.items.filter { !seen.contains($0.id) }
            apply(result)
        } catch {
            guard current == generation else { return }
            failure = CoachActionFailure(error)
        }
    }

    /// Creates a coach-owned exercise. It joins the catalog for this coach
    /// only, and needs just a name and a muscle group.
    public func createCustom(
        name: String, muscleGroup: CustomMuscleGroup, videoURL: String?, thumbnailURL: String?
    ) async -> Bool {
        let succeeded = await perform {
            let _: ExerciseDetail = try await self.client.send(CoachAPI.createExercise(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                muscleGroup: muscleGroup.rawValue,
                videoURL: videoURL.nilIfBlank, thumbnailURL: thumbnailURL.nilIfBlank
            ))
        }
        if succeeded {
            await reload()
        }
        return succeeded
    }

    /// Only a coach's own exercises can be deleted; the shared catalog cannot.
    @discardableResult
    public func deleteCustom(id: Int) async -> Bool {
        await perform {
            try await self.client.sendIgnoringResponse(CoachAPI.deleteExercise(id: id))
            self.exercises.removeAll { $0.id == id }
            self.totalCount = max(0, self.totalCount - 1)
        }
    }

    // MARK: - Internals

    private func fetch(page: Int) async throws -> Page<Exercise> {
        let search = filter.search.trimmingCharacters(in: .whitespacesAndNewlines)
        let custom: Bool? = switch filter.ownership {
        case .all: nil
        case .catalog: false
        case .mine: true
        }
        return try await client.sendPaged(CoachAPI.exercises(
            search: search.isEmpty ? nil : search,
            muscle: filter.muscle, equipment: filter.equipment,
            category: filter.category, difficulty: filter.difficulty,
            custom: custom, page: page, perPage: perPage
        ))
    }

    private func apply(_ result: Page<Exercise>) {
        page = result.page
        totalPages = result.totalPages
        totalCount = result.totalCount
    }
}

/// One exercise in full: instructions, muscles, and whether an animation
/// exists. Fetched on demand, because the list rows leave these out.
@MainActor
@Observable
public final class ExerciseDetailModel {
    public let exerciseID: Int
    public private(set) var detail: ExerciseDetail?
    public private(set) var failure: CoachActionFailure?

    @ObservationIgnored private let client: APIClient

    public init(client: APIClient, exerciseID: Int) {
        self.client = client
        self.exerciseID = exerciseID
    }

    /// Fetches the demonstration's bytes — only when the coach asks to see it,
    /// because each fetch draws on the provider's metered quota. The endpoint
    /// is shared by coaches and clients.
    public func animationLoader() -> @Sendable () async throws -> Data {
        let client = client
        let id = exerciseID
        return { try await client.data(for: ClientAPI.animation(exerciseID: id)) }
    }

    public func load() async {
        do {
            detail = try await client.send(CoachAPI.exercise(id: exerciseID))
            failure = nil
        } catch {
            failure = CoachActionFailure(error)
        }
    }
}
