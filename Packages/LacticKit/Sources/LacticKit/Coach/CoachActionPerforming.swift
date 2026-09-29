import Foundation

/// The submit-and-report shape every coach screen shares: one action at a
/// time, its failure kept as a reason for the screen to phrase.
///
/// A protocol rather than a base class because the models are `@Observable`
/// final classes; the conformers only need to expose the two properties.
@MainActor
protocol CoachActionPerforming: AnyObject {
    var isSubmitting: Bool { get set }
    var failure: CoachActionFailure? { get set }
}

extension CoachActionPerforming {
    /// Runs `work` unless another action is already in flight, recording why
    /// it failed. Returns whether it succeeded, so a sheet knows to dismiss.
    func perform(_ work: () async throws -> Void) async -> Bool {
        guard !isSubmitting else { return false }
        isSubmitting = true
        failure = nil
        defer { isSubmitting = false }
        do {
            try await work()
            return true
        } catch {
            failure = CoachActionFailure(error)
            return false
        }
    }
}
