import Foundation
import LacticKit
import LacticUI
import Observation

/// One exercise: the coach's reference material plus the client's own history.
@MainActor
@Observable
final class ExerciseDetailModel: LoadableSource {
    struct HistorySession: Sendable, Equatable, Identifiable {
        let id: Int
        let performedAt: Date?
        let sets: [SetLog]

        var bestWeight: Decimal {
            sets.map(\.weightKg).max() ?? .zero
        }

        var totalReps: Int {
            sets.reduce(0) { $0 + $1.reps }
        }

        var volumeKg: Decimal {
            sets.reduce(Decimal.zero) { total, set in
                total + set.weightKg * Decimal(set.reps)
            }
        }
    }

    struct Detail: Sendable, Equatable {
        let exercise: ExerciseDetail
        let history: [SetLog]

        var historySessions: [HistorySession] {
            var sessions: [HistorySession] = []
            var indices: [Int: Int] = [:]

            for set in history {
                let sessionID = set.workoutSessionID ?? -set.id
                if let index = indices[sessionID] {
                    let existing = sessions[index]
                    sessions[index] = HistorySession(
                        id: existing.id,
                        performedAt: existing.performedAt ?? set.performedAt,
                        sets: existing.sets + [set]
                    )
                } else {
                    indices[sessionID] = sessions.count
                    sessions.append(
                        HistorySession(id: sessionID, performedAt: set.performedAt, sets: [set])
                    )
                }
            }
            return sessions
        }

        var bestWeight: Decimal? {
            history.map(\.weightKg).max()
        }

        var totalReps: Int {
            history.reduce(0) { $0 + $1.reps }
        }

        var totalVolumeKg: Decimal {
            history.reduce(Decimal.zero) { total, set in
                total + set.weightKg * Decimal(set.reps)
            }
        }

        var datedHistorySessions: [HistorySession] {
            historySessions
                .filter { $0.performedAt != nil }
                .sorted { ($0.performedAt ?? .distantPast) < ($1.performedAt ?? .distantPast) }
        }

        var bestWeightChange: Decimal? {
            guard let first = datedHistorySessions.first, let last = datedHistorySessions.last,
                  first.id != last.id
            else { return nil }
            return last.bestWeight - first.bestWeight
        }
    }

    private(set) var state: Loadable<Detail> = .idle

    private let client: APIClient
    private let exerciseID: Int

    init(client: APIClient, exerciseID: Int) {
        self.client = client
        self.exerciseID = exerciseID
    }

    func load() async {
        if case .loaded = state {
            return
        }
        await reload()
    }

    func reload() async {
        state = .loading
        do {
            async let exerciseTask: ExerciseDetail = client.send(ClientAPI.exercise(id: exerciseID))
            async let historyTask: [SetLog] = client.send(ClientAPI.exerciseHistory(id: exerciseID))
            let (exercise, history) = try await (exerciseTask, historyTask)
            state = .loaded(Detail(exercise: exercise, history: history))
        } catch {
            state = .failed((error as? APIError)?.message ?? error.localizedDescription)
        }
    }

    /// Fetches the demonstration's bytes. Authenticated and metered, so this is
    /// only ever called when the user opens the demonstration.
    func loadAnimation() -> @Sendable () async throws -> Data {
        let client = client
        let id = exerciseID
        return { try await client.data(for: ClientAPI.animation(exerciseID: id)) }
    }
}
