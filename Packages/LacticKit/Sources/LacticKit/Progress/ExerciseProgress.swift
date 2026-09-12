import Foundation
import LacticCore

/// One exercise's reference material and the client's own history with it.
///
/// A value type over what the API returned, with every metric derived rather
/// than stored: the same set logs answer "best weight", "total reps" and "how
/// much has this moved", and deriving them keeps those answers from drifting
/// apart.
public struct ExerciseProgress: Sendable, Equatable {
    public let exercise: ExerciseDetail
    /// Flat, as the API returns it: `GET /client/exercises/:id/history` has no
    /// notion of a session, only rows.
    public let history: [SetLog]

    public init(exercise: ExerciseDetail, history: [SetLog]) {
        self.exercise = exercise
        self.history = history
    }

    /// One training session's worth of sets for this exercise.
    public struct Session: Sendable, Equatable, Identifiable {
        public let id: Int
        public let performedAt: Date?
        public let sets: [SetLog]

        public init(id: Int, performedAt: Date?, sets: [SetLog]) {
            self.id = id
            self.performedAt = performedAt
            self.sets = sets
        }

        public var bestWeight: Decimal {
            sets.map(\.weightKg).max() ?? .zero
        }

        public var totalReps: Int {
            sets.reduce(0) { $0 + $1.reps }
        }

        public var volumeKg: Decimal {
            sets.reduce(Decimal.zero) { total, set in
                total + set.weightKg * Decimal(set.reps)
            }
        }
    }

    /// Groups the flat rows back into sessions, preserving the order they
    /// arrived in.
    ///
    /// A row with no `workout_session_id` — the shape older responses had —
    /// becomes its own session keyed on the negated set id, so it can never
    /// collide with a real session id and never silently merges unrelated sets.
    public var historySessions: [Session] {
        var sessions: [Session] = []
        var indices: [Int: Int] = [:]

        for set in history {
            let sessionID = set.workoutSessionID ?? -set.id
            if let index = indices[sessionID] {
                let existing = sessions[index]
                sessions[index] = Session(
                    id: existing.id,
                    performedAt: existing.performedAt ?? set.performedAt,
                    sets: existing.sets + [set]
                )
            } else {
                indices[sessionID] = sessions.count
                sessions.append(Session(id: sessionID, performedAt: set.performedAt, sets: [set]))
            }
        }
        return sessions
    }

    public var bestWeight: Decimal? {
        history.map(\.weightKg).max()
    }

    public var totalReps: Int {
        history.reduce(0) { $0 + $1.reps }
    }

    public var totalVolumeKg: Decimal {
        history.reduce(Decimal.zero) { total, set in
            total + set.weightKg * Decimal(set.reps)
        }
    }

    /// Sessions that can be placed on a timeline, oldest first. Undated rows
    /// are excluded rather than guessed at — a trend line through an unknown
    /// date would be a fabrication.
    public var datedHistorySessions: [Session] {
        historySessions
            .filter { $0.performedAt != nil }
            .sorted { ($0.performedAt ?? .distantPast) < ($1.performedAt ?? .distantPast) }
    }

    /// How much the heaviest set has moved since the first recorded session.
    ///
    /// `nil` with fewer than two dated sessions: a single session is a starting
    /// point, not progress, and reporting zero would imply a plateau.
    public var bestWeightChange: Decimal? {
        guard let first = datedHistorySessions.first, let last = datedHistorySessions.last,
              first.id != last.id
        else { return nil }
        return last.bestWeight - first.bestWeight
    }
}
