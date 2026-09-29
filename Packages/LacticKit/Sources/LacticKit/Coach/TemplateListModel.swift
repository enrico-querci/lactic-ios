import Foundation
import Observation

/// Saved workouts, reusable in any programme. Created from a workout in the
/// programme builder and applied there too; this is where they are reviewed
/// and cleared out.
@MainActor
@Observable
public final class TemplateListModel: CoachActionPerforming {
    public private(set) var templates: [WorkoutTemplate] = []
    public private(set) var hasLoaded = false
    public private(set) var isLoading = false
    public internal(set) var isSubmitting = false
    public internal(set) var failure: CoachActionFailure?

    @ObservationIgnored private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            templates = try await client.send(CoachAPI.workoutTemplates)
            hasLoaded = true
            failure = nil
        } catch {
            if error.isCancellation {
                return
            }
            failure = CoachActionFailure(error)
        }
    }

    /// Deleting a template never touches the workouts already made from it.
    @discardableResult
    public func delete(id: Int) async -> Bool {
        await perform {
            try await self.client.sendIgnoringResponse(CoachAPI.deleteWorkoutTemplate(id: id))
            self.templates.removeAll { $0.id == id }
        }
    }
}
