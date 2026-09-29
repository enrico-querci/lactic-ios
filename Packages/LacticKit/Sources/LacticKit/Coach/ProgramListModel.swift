import Foundation
import Observation

/// The coach's programmes: reusable templates, each assignable to any number
/// of clients (AGENTS.md ADR #3).
@MainActor
@Observable
public final class ProgramListModel: CoachActionPerforming {
    public private(set) var programs: [Program] = []
    /// Separate from `programs.isEmpty`, so an empty library reads as empty
    /// rather than as still loading.
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
            programs = try await client.send(CoachAPI.programs)
            hasLoaded = true
            failure = nil
        } catch {
            failure = CoachActionFailure(error)
        }
    }

    /// Returns the new programme, so the screen can open it in the builder
    /// straight away — an empty programme is only a starting point.
    public func create(name: String, description: String?) async -> Program? {
        var created: Program?
        _ = await perform {
            let program: Program = try await self.client.send(
                CoachAPI.createProgram(name: name, description: description.nilIfBlank)
            )
            self.programs.append(program)
            created = program
        }
        return created
    }

    /// Deleting a programme also deletes its assignments and the sessions
    /// clients logged against them — the server cascades.
    @discardableResult
    public func delete(id: Int) async -> Bool {
        await perform {
            try await self.client.sendIgnoringResponse(CoachAPI.deleteProgram(id: id))
            self.programs.removeAll { $0.id == id }
        }
    }
}

extension String? {
    /// Blank input means "none" to the API, not an empty string worth storing.
    var nilIfBlank: String? {
        guard let self else { return nil }
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
