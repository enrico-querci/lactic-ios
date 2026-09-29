import Foundation
import LacticCore
import Observation

/// Which programme each client follows, from when, and whether it is running.
///
/// Scoped to one client when `clientID` is set — the same model backs the
/// Assignments destination and a client's own detail screen.
@MainActor
@Observable
public final class AssignmentListModel: CoachActionPerforming {
    public let clientID: Int?

    /// `nil` shows every status. Call `load()` after changing it; the filter
    /// is applied server-side.
    public var statusFilter: AssignmentStatus?

    public private(set) var assignments: [ProgramAssignment] = []
    public private(set) var hasLoaded = false
    public private(set) var isLoading = false
    public internal(set) var isSubmitting = false
    public internal(set) var failure: CoachActionFailure?

    @ObservationIgnored private let client: APIClient

    public init(client: APIClient, clientID: Int? = nil) {
        self.client = client
        self.clientID = clientID
    }

    /// Newest start first: the assignment a coach is most likely to adjust is
    /// the one that just began.
    public var orderedAssignments: [ProgramAssignment] {
        assignments.sorted { ($0.startDate, $0.id) > ($1.startDate, $1.id) }
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            assignments = try await client.send(
                CoachAPI.programAssignments(clientID: clientID, status: statusFilter)
            )
            hasLoaded = true
            failure = nil
        } catch {
            if error.isCancellation {
                return
            }
            failure = CoachActionFailure(error)
        }
    }

    /// Only `active` assignments reach the client app, so pausing or
    /// completing one takes it off the client's programme list.
    @discardableResult
    public func setStatus(_ status: AssignmentStatus, forAssignment id: Int) async -> Bool {
        await perform {
            let updated: ProgramAssignment = try await self.client.send(
                CoachAPI.updateProgramAssignment(id: id, status: status)
            )
            self.replace(updated)
        }
    }

    /// Deleting an assignment also deletes the sessions logged against it.
    @discardableResult
    public func delete(id: Int) async -> Bool {
        await perform {
            try await self.client.sendIgnoringResponse(CoachAPI.deleteProgramAssignment(id: id))
            self.assignments.removeAll { $0.id == id }
        }
    }

    /// Merges an assignment made elsewhere — the new-assignment sheet — so the
    /// list shows it without a reload, provided it matches what is on screen.
    public func didCreate(_ assignment: ProgramAssignment) {
        guard clientID == nil || assignment.client.id == clientID,
              statusFilter == nil || assignment.status == statusFilter
        else { return }
        replace(assignment)
    }

    private func replace(_ assignment: ProgramAssignment) {
        if let index = assignments.firstIndex(where: { $0.id == assignment.id }) {
            // A status change can move it out of the filtered view.
            if let statusFilter, assignment.status != statusFilter {
                assignments.remove(at: index)
            } else {
                assignments[index] = assignment
            }
        } else {
            assignments.append(assignment)
        }
    }
}

/// The new-assignment form: which programme, for which client, from when.
@MainActor
@Observable
public final class NewAssignmentModel: CoachActionPerforming {
    public private(set) var programs: [Program] = []
    public private(set) var clients: [User] = []
    public private(set) var hasLoaded = false
    public internal(set) var isSubmitting = false
    public internal(set) var failure: CoachActionFailure?

    @ObservationIgnored private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// Both lists, concurrently: the form offers nothing until it has both.
    public func load() async {
        do {
            async let programs: [Program] = client.send(CoachAPI.programs)
            async let clients: [User] = client.send(CoachAPI.clients)
            (self.programs, self.clients) = try await (programs, clients)
            hasLoaded = true
            failure = nil
        } catch {
            if error.isCancellation {
                return
            }
            failure = CoachActionFailure(error)
        }
    }

    /// Returns the new assignment, which starts `active`, for the screen to
    /// merge into whatever list it came from.
    public func create(
        programID: Int, clientID: Int, startDate: CalendarDate, notes: String?
    ) async -> ProgramAssignment? {
        var created: ProgramAssignment?
        _ = await perform {
            created = try await self.client.send(CoachAPI.createProgramAssignment(
                programID: programID, clientID: clientID, startDate: startDate, notes: notes.nilIfBlank
            ))
        }
        return created
    }
}
