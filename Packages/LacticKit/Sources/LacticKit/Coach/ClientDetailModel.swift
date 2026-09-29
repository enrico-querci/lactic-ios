import Foundation
import Observation

/// One client as their coach sees them: who they are, the sessions they have
/// logged against this coach's programmes, and what they are assigned.
@MainActor
@Observable
public final class ClientDetailModel {
    public let clientID: Int

    public private(set) var user: User?
    /// Newest first, as the API orders them. Only sessions against this
    /// coach's programmes — a client's history with a previous coach stays
    /// private.
    public private(set) var sessions: [WorkoutSession] = []
    public let assignments: AssignmentListModel
    public private(set) var isLoading = false
    public private(set) var failure: CoachActionFailure?

    @ObservationIgnored private let client: APIClient

    public init(client: APIClient, clientID: Int) {
        self.client = client
        self.clientID = clientID
        assignments = AssignmentListModel(client: client, clientID: clientID)
    }

    public var completedSessionCount: Int {
        sessions.filter { $0.completedAt != nil }.count
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let user: User = client.send(CoachAPI.client(id: clientID))
            async let sessions: [WorkoutSession] = client.send(CoachAPI.clientProgress(clientID: clientID))
            async let assignments: Void = assignments.load()
            (self.user, self.sessions) = try await (user, sessions)
            await assignments
            failure = nil
        } catch {
            if error.isCancellation {
                return
            }
            failure = CoachActionFailure(error)
        }
    }
}

/// One logged session in full: every exercise and set the client recorded.
@MainActor
@Observable
public final class ClientSessionModel {
    public let clientID: Int
    public let sessionID: Int
    public private(set) var session: WorkoutSessionDetail?
    public private(set) var failure: CoachActionFailure?

    @ObservationIgnored private let client: APIClient

    public init(client: APIClient, clientID: Int, sessionID: Int) {
        self.client = client
        self.clientID = clientID
        self.sessionID = sessionID
    }

    /// The session with its exercises named and in the coach's `A`-`Z` order.
    /// Each log carries its own exercise name and letter, so no second fetch of
    /// the workout is needed to label it.
    public var summary: SessionSummary? {
        guard let session else { return nil }
        let references = Dictionary(
            session.exerciseLogs.map { log in
                (log.workoutExerciseID, SessionSummary.ExerciseReference(
                    exerciseID: log.exerciseID, name: log.exerciseName, position: log.position
                ))
            },
            uniquingKeysWith: { first, _ in first }
        )
        return SessionSummary(session: session, workoutName: session.workoutName, exerciseReferences: references)
    }

    public func load() async {
        do {
            session = try await client.send(CoachAPI.clientSession(clientID: clientID, sessionID: sessionID))
            failure = nil
        } catch {
            if error.isCancellation {
                return
            }
            failure = CoachActionFailure(error)
        }
    }
}
