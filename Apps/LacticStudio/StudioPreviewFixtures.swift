#if DEBUG
    import Foundation

    /// Deterministic API responses for the design preview, keyed by path, so
    /// every Studio destination can be reviewed without an account or a
    /// server. Shapes follow the real blueprints.
    enum StudioPreviewFixtures {
        static func response(method: String, path: String, request: URLRequest) -> (Int, String)? {
            let parts = path.split(separator: "/").map(String.init)
            guard let coach = parts.firstIndex(of: "coach") else { return nil }
            let rest = Array(parts[(coach + 1)...])

            switch (method, rest.first, rest.count) {
            case ("GET", "clients", 2):
                return (200, client(id: Int(rest[1]) ?? 7))
            case ("GET", "clients", 3) where rest[2] == "progress":
                return (200, sessionsJSON)
            case ("GET", "clients", 4) where rest[2] == "progress":
                return (200, sessionDetailJSON)
            case ("GET", "program_assignments", 1):
                let query = request.url
                    .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems ?? []
                let clientID = query.first { $0.name == "client_id" }?.value.flatMap(Int.init)
                let status = query.first { $0.name == "status" }?.value
                let rows = assignments.filter { row in
                    (clientID == nil || row.clientID == clientID) && (status == nil || row.status == status)
                }
                return (200, "[" + rows.map(\.json).joined(separator: ",") + "]")
            case ("POST", "program_assignments", 1):
                return (201, assignments[0].json)
            case ("PATCH", "program_assignments", 2):
                return (200, assignments.first { String($0.id) == rest[1] }?.json ?? assignments[0].json)
            case ("GET", "programs", 1):
                return (200, "[" + programs.map { program(id: $0.id, name: $0.name) }.joined(separator: ",") + "]")
            default:
                return nil
            }
        }

        // MARK: - Clients and sessions

        private static func client(id: Int) -> String {
            let name = id == 8 ? "Dario Romano" : "Alice Bianchi"
            let email = id == 8 ? "dario@example.com" : "alice@example.com"
            return #"{"id":\#(id),"avatar_url":null,"email":"\#(email)","name":"\#(name)","role":"client"}"#
        }

        private static let sessionsJSON = """
        [
          {"id":32,"workout_id":8,"workout_name":"Upper A","started_at":"2026-09-29T06:50:00.000Z",\
        "completed_at":null,"notes":null},
          {"id":31,"workout_id":8,"workout_name":"Upper A","started_at":"2026-09-28T07:02:00.000Z",\
        "completed_at":"2026-09-28T08:05:00.000Z","notes":"Felt strong, bench moved well."},
          {"id":30,"workout_id":9,"workout_name":"Lower A","started_at":"2026-09-25T18:10:00.000Z",\
        "completed_at":"2026-09-25T19:02:00.000Z","notes":null}
        ]
        """

        private static let sessionDetailJSON = """
        {"id":31,"workout_id":8,"workout_name":"Upper A","started_at":"2026-09-28T07:02:00.000Z",\
        "completed_at":"2026-09-28T08:05:00.000Z","notes":"Felt strong, bench moved well.","exercise_logs":[\
        {"id":1,"workout_exercise_id":11,"exercise_id":101,"exercise_name":"Barbell Bench Press","position":"A",\
        "notes":null,"photo_url":null,"set_logs":[\
        {"id":1,"position":1,"weight_kg":"80.0","reps":8},{"id":2,"position":2,"weight_kg":"80.0","reps":8},\
        {"id":3,"position":3,"weight_kg":"82.5","reps":6}]},\
        {"id":2,"workout_exercise_id":12,"exercise_id":102,"exercise_name":"Seated Cable Row","position":"B",\
        "notes":"Paused at the chest.","photo_url":null,"set_logs":[\
        {"id":4,"position":1,"weight_kg":"60.0","reps":10},{"id":5,"position":2,"weight_kg":"60.0","reps":10}]}]}
        """

        // MARK: - Programmes and assignments

        private static let programs: [(id: Int, name: String)] = [
            (3, "Upper/Lower Split"), (4, "Hypertrophy Block"),
        ]

        static func program(id: Int, name: String) -> String {
            #"{"id":\#(id),"name":"\#(name)","description":"Four days a week.","#
                + #""created_at":"2026-09-01T10:00:00.000Z"}"#
        }

        private struct AssignmentRow {
            let id: Int
            let programID: Int
            let clientID: Int
            let status: String
            let start: String
            let notes: String?

            var json: String {
                let programName = programs.first { $0.id == programID }?.name ?? "Programme"
                let notes = notes.map { #""\#($0)""# } ?? "null"
                return """
                {"id":\(id),"start_date":"\(start)","status":"\(status)","notes":\(notes),\
                "program":\(program(id: programID, name: programName)),"client":\(client(id: clientID))}
                """
            }
        }

        private static let assignments = [
            AssignmentRow(
                id: 1, programID: 3, clientID: 7, status: "active", start: "2026-09-01",
                notes: "Keep two reps in reserve on the main lifts."
            ),
            AssignmentRow(id: 2, programID: 4, clientID: 8, status: "paused", start: "2026-08-18", notes: nil),
            AssignmentRow(id: 3, programID: 3, clientID: 8, status: "completed", start: "2026-06-02", notes: nil),
        ]
    }
#endif
