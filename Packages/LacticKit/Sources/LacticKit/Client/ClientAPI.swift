import Foundation
import LacticCore

/// Every endpoint the Lactic client app uses, as `Endpoint` values.
///
/// Kept as a namespace of static factories rather than methods on a service so
/// they can be constructed and asserted in tests without a network stack.
public enum ClientAPI {
    // MARK: - Auth

    public static func devLogin(email: String) throws -> Endpoint {
        // Top-level params: AuthController does not use a Rails wrapper.
        try Endpoint(
            method: .post, path: "/auth/dev_login",
            body: JSONCoding.encoder.encode(["email": email]),
            requiresAuthentication: false
        )
    }

    public static func signIn(provider: String, idToken: String, invitationToken: String?) throws -> Endpoint {
        var payload = ["provider": provider, "id_token": idToken]
        payload["invitation_token"] = invitationToken
        return try Endpoint(
            method: .post, path: "/auth",
            body: JSONCoding.encoder.encode(payload),
            requiresAuthentication: false
        )
    }

    public static func refresh(refreshToken: String) throws -> Endpoint {
        try Endpoint(
            method: .post, path: "/auth/refresh",
            body: JSONCoding.encoder.encode(["refresh_token": refreshToken]),
            requiresAuthentication: false
        )
    }

    /// Always answers 204, even for a token it does not recognise, and revokes
    /// only the token presented — other devices stay signed in.
    public static func signOut(refreshToken: String) throws -> Endpoint {
        try Endpoint(
            method: .delete, path: "/auth",
            body: JSONCoding.encoder.encode(["refresh_token": refreshToken]),
            requiresAuthentication: false
        )
    }

    // MARK: - Profile

    public static var me: Endpoint {
        Endpoint(path: "/me")
    }

    /// Only `name` and `avatar_url` are permitted; `locale`, `email` and `role`
    /// are dropped silently by strong params rather than rejected.
    public static func updateProfile(name: String?, avatarURL: String?) throws -> Endpoint {
        var payload: [String: String] = [:]
        payload["name"] = name
        payload["avatar_url"] = avatarURL
        return try Endpoint(
            method: .patch, path: "/me",
            body: JSONCoding.encoder.encode(RailsWrapped(key: "user", payload: payload))
        )
    }

    // MARK: - Programs

    /// Returns active assignments only — the API filters, not the client.
    public static var programs: Endpoint {
        Endpoint(path: "/client/programs")
    }

    /// Takes the **program** id, not the assignment id.
    public static func program(id: Int) -> Endpoint {
        Endpoint(path: "/client/programs/\(id)")
    }

    public static func workout(id: Int) -> Endpoint {
        Endpoint(path: "/client/workouts/\(id)")
    }

    // MARK: - Exercises

    public static func exercises(
        search: String? = nil, muscle: String? = nil, equipment: String? = nil,
        page: Int = 1, perPage: Int = 25
    ) -> Endpoint {
        var query = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
        ]
        if let search {
            query.append(URLQueryItem(name: "search", value: search))
        }
        if let muscle {
            query.append(URLQueryItem(name: "muscle", value: muscle))
        }
        if let equipment {
            query.append(URLQueryItem(name: "equipment", value: equipment))
        }
        return Endpoint(path: "/client/exercises", query: query)
    }

    public static func exercise(id: Int) -> Endpoint {
        Endpoint(path: "/client/exercises/\(id)")
    }

    /// A flat list of sets with no dates and no session reference, so it cannot
    /// be grouped by session. Ordered newest session first.
    public static func exerciseHistory(id: Int) -> Endpoint {
        Endpoint(path: "/client/exercises/\(id)/history")
    }

    /// Authenticated, and proxies GIF bytes rather than redirecting. An upstream
    /// failure surfaces as 502 or 503 — deliberately never 401, so it cannot
    /// trigger a token refresh.
    public static func animation(exerciseID: Int) -> Endpoint {
        Endpoint(path: "/exercises/\(exerciseID)/animation")
    }

    // MARK: - Sessions and logging

    public static var workoutSessions: Endpoint {
        Endpoint(path: "/client/workout_sessions")
    }

    public static func workoutSession(id: Int) -> Endpoint {
        Endpoint(path: "/client/workout_sessions/\(id)")
    }

    public static func startSession(
        workoutID: Int, programAssignmentID: Int, startedAt: Date
    ) throws -> Endpoint {
        struct Payload: Encodable {
            let workoutID: Int
            let programAssignmentID: Int
            let startedAt: Date
            enum CodingKeys: String, CodingKey {
                case workoutID = "workout_id"
                case programAssignmentID = "program_assignment_id"
                case startedAt = "started_at"
            }
        }
        let payload = Payload(
            workoutID: workoutID, programAssignmentID: programAssignmentID, startedAt: startedAt
        )
        return try Endpoint(
            method: .post, path: "/client/workout_sessions",
            body: JSONCoding.encoder.encode(RailsWrapped(key: "workout_session", payload: payload))
        )
    }

    public static func updateSession(
        id: Int, completedAt: Date? = nil, notes: String? = nil
    ) throws -> Endpoint {
        struct Payload: Encodable {
            let completedAt: Date?
            let notes: String?
            enum CodingKeys: String, CodingKey {
                case completedAt = "completed_at"
                case notes
            }
        }
        return try Endpoint(
            method: .patch, path: "/client/workout_sessions/\(id)",
            body: JSONCoding.encoder.encode(
                RailsWrapped(key: "workout_session", payload: Payload(completedAt: completedAt, notes: notes))
            )
        )
    }

    /// `workout_session_id` is read directly from the params hash before strong
    /// params run, so omitting it raises a `NoMethodError` and returns a plain
    /// 500 rather than a 400. It is never optional.
    public static func createExerciseLog(
        workoutSessionID: Int, workoutExerciseID: Int, notes: String? = nil
    ) throws -> Endpoint {
        struct Payload: Encodable {
            let workoutSessionID: Int
            let workoutExerciseID: Int
            let notes: String?
            enum CodingKeys: String, CodingKey {
                case workoutSessionID = "workout_session_id"
                case workoutExerciseID = "workout_exercise_id"
                case notes
            }
        }
        let payload = Payload(
            workoutSessionID: workoutSessionID, workoutExerciseID: workoutExerciseID, notes: notes
        )
        return try Endpoint(
            method: .post, path: "/client/exercise_logs",
            body: JSONCoding.encoder.encode(RailsWrapped(key: "exercise_log", payload: payload))
        )
    }

    public static func updateExerciseLog(id: Int, notes: String?) throws -> Endpoint {
        try Endpoint(
            method: .patch, path: "/client/exercise_logs/\(id)",
            body: JSONCoding.encoder.encode(
                RailsWrapped(key: "exercise_log", payload: ["notes": notes])
            )
        )
    }

    /// `reps` must be greater than zero and `position` is unique per log, both
    /// enforced server-side. Never send zeroes for a newly added set: pre-fill
    /// it from the coach's target, or the create fails with a 422.
    public static func createSetLog(
        exerciseLogID: Int, position: Int, weightKg: Decimal, reps: Int
    ) throws -> Endpoint {
        struct Payload: Encodable {
            let exerciseLogID: Int
            let position: Int
            let weightKg: Decimal
            let reps: Int
            enum CodingKeys: String, CodingKey {
                case exerciseLogID = "exercise_log_id"
                case position, reps
                case weightKg = "weight_kg"
            }
        }
        let payload = Payload(
            exerciseLogID: exerciseLogID, position: position, weightKg: weightKg, reps: reps
        )
        return try Endpoint(
            method: .post, path: "/client/set_logs",
            body: JSONCoding.encoder.encode(RailsWrapped(key: "set_log", payload: payload))
        )
    }

    public static func updateSetLog(id: Int, weightKg: Decimal?, reps: Int?) throws -> Endpoint {
        struct Payload: Encodable {
            let weightKg: Decimal?
            let reps: Int?
            enum CodingKeys: String, CodingKey {
                case weightKg = "weight_kg"
                case reps
            }
        }
        return try Endpoint(
            method: .patch, path: "/client/set_logs/\(id)",
            body: JSONCoding.encoder.encode(
                RailsWrapped(key: "set_log", payload: Payload(weightKg: weightKg, reps: reps))
            )
        )
    }

    public static func deleteSetLog(id: Int) -> Endpoint {
        Endpoint(method: .delete, path: "/client/set_logs/\(id)")
    }

    // MARK: - Onboarding and account

    /// Unauthenticated, and answers 200 for accepted, revoked and expired
    /// invitations too. Branch on `status`.
    public static func invitation(token: String) -> Endpoint {
        Endpoint(path: "/client_invitations/\(escapingPathSegment(token))", requiresAuthentication: false)
    }

    public static func acceptInvitation(token: String) -> Endpoint {
        Endpoint(method: .post, path: "/client_invitations/\(escapingPathSegment(token))/accept")
    }

    /// Escapes a value being interpolated into a **single** path segment.
    ///
    /// Not `.urlPathAllowed`, which permits `/` and would let a value split the
    /// path and address a different route. Invitation tokens are
    /// `SecureRandom.urlsafe_base64(32)` and so contain only `A-Za-z0-9-_`
    /// today; this is defence against that changing, not a live bug.
    private static func escapingPathSegment(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/+")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    /// Singular path, and it cascades: assignments, sessions, logs and tokens
    /// all go with the user.
    public static var deleteAccount: Endpoint {
        Endpoint(method: .delete, path: "/client/account")
    }
}
