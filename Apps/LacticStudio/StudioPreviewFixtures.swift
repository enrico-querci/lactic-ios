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
            return clientResponse(method: method, rest: rest, request: request)
                ?? programmeResponse(method: method, rest: rest)
        }

        // MARK: - Routing

        private static func clientResponse(method: String, rest: [String], request: URLRequest) -> (Int, String)? {
            switch (method, rest.first, rest.count) {
            case ("GET", "clients", 2):
                (200, client(id: Int(rest[1]) ?? 7))
            case ("GET", "clients", 3) where rest[2] == "progress":
                (200, sessionsJSON)
            case ("GET", "clients", 4) where rest[2] == "progress":
                (200, sessionDetailJSON)
            case ("GET", "program_assignments", 1):
                (200, assignmentList(query: request.url))
            case ("POST", "program_assignments", 1):
                (201, assignments[0].json)
            case ("PATCH", "program_assignments", 2):
                (200, (assignments.first { String($0.id) == rest[1] } ?? assignments[0]).json)
            default:
                nil
            }
        }

        private static func programmeResponse(method: String, rest: [String]) -> (Int, String)? {
            guard method == "GET" else { return nil }
            switch (rest.first, rest.count) {
            case ("programs", 1):
                return (200, array(programs.map(\.json)))
            case ("programs", 2):
                return (200, programDetailJSON)
            case ("programs", 6) where rest[4] == "workouts":
                return (200, workoutDetailJSON)
            case ("workout_templates", 1):
                return (200, templatesJSON)
            case ("exercise_taxonomy", 1):
                return (200, taxonomyJSON)
            case ("exercises", 1):
                return (200, array(catalog.map(\.json)))
            case ("exercises", 2):
                return (200, exerciseDetailJSON)
            default:
                return nil
            }
        }

        private static func array(_ items: [String]) -> String {
            "[" + items.joined(separator: ",") + "]"
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

        private struct ProgramRow {
            let id: Int
            let name: String

            var json: String {
                #"{"id":\#(id),"name":"\#(name)","description":"Four days a week.","#
                    + #""created_at":"2026-09-01T10:00:00.000Z"}"#
            }
        }

        private static let programs = [
            ProgramRow(id: 3, name: "Upper/Lower Split"),
            ProgramRow(id: 4, name: "Hypertrophy Block"),
        ]

        private struct AssignmentRow {
            let id: Int
            let programID: Int
            let clientID: Int
            let status: String
            let start: String
            var notes: String?

            var json: String {
                let program = programs.first { $0.id == programID } ?? programs[0]
                let notes = notes.map { #""\#($0)""# } ?? "null"
                return """
                {"id":\(id),"start_date":"\(start)","status":"\(status)","notes":\(notes),\
                "program":\(program.json),"client":\(client(id: clientID))}
                """
            }
        }

        private static let assignments = [
            AssignmentRow(
                id: 1, programID: 3, clientID: 7, status: "active", start: "2026-09-01",
                notes: "Keep two reps in reserve on the main lifts."
            ),
            AssignmentRow(id: 2, programID: 4, clientID: 8, status: "paused", start: "2026-08-18"),
            AssignmentRow(id: 3, programID: 3, clientID: 8, status: "completed", start: "2026-06-02"),
        ]

        /// Applies the same `client_id` and `status` filters the API does.
        private static func assignmentList(query url: URL?) -> String {
            let query = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems ?? []
            let clientID = query.first { $0.name == "client_id" }?.value.flatMap(Int.init)
            let status = query.first { $0.name == "status" }?.value
            let rows = assignments.filter { row in
                (clientID == nil || row.clientID == clientID) && (status == nil || row.status == status)
            }
            return array(rows.map(\.json))
        }

        // MARK: - Programme structure

        private static func workout(id: Int, name: String, day: Int, volume: String) -> String {
            #"{"id":\#(id),"name":"\#(name)","day":\#(day),"volume_sets":\#(volume)}"#
        }

        private static let programDetailJSON = """
        {"id":3,"name":"Upper/Lower Split","description":"Four days a week, alternating upper and lower.",\
        "created_at":"2026-09-01T10:00:00.000Z","weeks":[\
        {"id":4,"position":1,"workouts":[\
        \(workout(id: 8, name: "Upper A", day: 1, volume: #"{"Chest":6,"Back":6,"Shoulders":3}"#)),\
        \(workout(id: 9, name: "Lower A", day: 2, volume: #"{"Quadriceps":6,"Hamstrings":4,"Glutes":3}"#)),\
        \(workout(id: 10, name: "Upper B", day: 4, volume: #"{"Back":6,"Chest":4,"Biceps":3}"#)),\
        \(workout(id: 11, name: "Lower B", day: 5, volume: "{}"))]},\
        {"id":5,"position":2,"workouts":[]}]}
        """

        private struct CatalogRow {
            let id: Int
            let name: String
            let muscle: String
            let equipment: String
            var isCustom = false

            var json: String {
                let muscleJSON = isCustom
                    ? "null"
                    : #"{"key":"\#(muscle.lowercased())","name":"\#(muscle)","region":null}"#
                let equipmentJSON = #"[{"key":"\#(equipment.lowercased())","name":"\#(equipment)"}]"#
                return """
                {"id":\(id),"name":"\(name)","is_custom":\(isCustom),"category":"strength",\
                "difficulty":"intermediate","mechanic":null,"force":null,"prescription_type":"reps",\
                "active":true,"assignable":true,"primary_muscle":\(muscleJSON),"equipment":\(equipmentJSON),\
                "has_animation":false,"animation_url":null,"muscle_group":"\(muscle)",\
                "video_url":null,"thumbnail_url":null}
                """
            }
        }

        private static let catalog = [
            CatalogRow(id: 101, name: "Barbell Bench Press", muscle: "Chest", equipment: "Barbell"),
            CatalogRow(id: 102, name: "Seated Cable Row", muscle: "Back", equipment: "Cable"),
            CatalogRow(id: 103, name: "Overhead Press", muscle: "Shoulders", equipment: "Barbell"),
            CatalogRow(id: 104, name: "Back Squat", muscle: "Quadriceps", equipment: "Barbell"),
            CatalogRow(id: 105, name: "Romanian Deadlift", muscle: "Hamstrings", equipment: "Barbell"),
            CatalogRow(id: 106, name: "Landmine Press", muscle: "Shoulders", equipment: "Barbell", isCustom: true),
        ]

        /// One prescribed exercise. Optional fields are raw JSON fragments, so
        /// `nil` becomes `null`.
        private struct PrescriptionRow {
            let id: Int
            let position: String
            let exercise: CatalogRow
            let reps: Int
            var rir: Int?
            var weight: String?
            var notes: String?

            var json: String {
                let rirJSON = rir.map(String.init) ?? "null"
                let weightJSON = weight.map { #""\#($0)""# } ?? "null"
                let notesJSON = notes.map { #""\#($0)""# } ?? "null"
                return """
                {"id":\(id),"position":"\(position)","sets":3,"reps":\(reps),"rest_seconds":120,\
                "rir":\(rirJSON),"weight":\(weightJSON),"notes":\(notesJSON),"exercise":\(exercise.json)}
                """
            }
        }

        private static let prescriptions = [
            PrescriptionRow(
                id: 11, position: "A", exercise: catalog[0], reps: 8, rir: 2, weight: "80.0",
                notes: "Pause on the chest"
            ),
            PrescriptionRow(id: 12, position: "B", exercise: catalog[1], reps: 10),
            PrescriptionRow(id: 13, position: "C", exercise: catalog[2], reps: 8, rir: 1, weight: "40.0"),
        ]

        private static let workoutDetailJSON = """
        {"id":8,"name":"Upper A","day":1,"volume_sets":{"Chest":6,"Back":6,"Shoulders":3},\
        "workout_exercises":\(array(prescriptions.map(\.json)))}
        """

        private static let exerciseDetailJSON = """
        {"id":101,"name":"Barbell Bench Press","is_custom":false,"category":"strength","difficulty":"intermediate",\
        "mechanic":"compound","force":"push","prescription_type":"reps","active":true,"assignable":true,\
        "primary_muscle":{"key":"chest","name":"Chest","region":null},\
        "equipment":[{"key":"barbell","name":"Barbell"},{"key":"bench","name":"Bench"}],\
        "has_animation":true,"animation_url":"/api/v1/exercises/101/animation","muscle_group":"Chest",\
        "video_url":null,"thumbnail_url":null,"locale":"en",\
        "description":"A horizontal press that builds the chest, front shoulders and triceps.",\
        "instructions":["Lie on the bench with your eyes under the bar.",\
        "Lower the bar to mid-chest with elbows at about 45 degrees.",\
        "Press back up until your arms are straight."],\
        "secondary_muscles":[{"key":"triceps","name":"Triceps"},{"key":"shoulders","name":"Front delts"}]}
        """

        private static let templatesJSON = """
        [{"id":1,"name":"Push day","source_workout_id":8,"created_at":"2026-09-10T10:00:00.000Z"},\
        {"id":2,"name":"Leg day","source_workout_id":9,"created_at":"2026-09-12T10:00:00.000Z"}]
        """

        private static let taxonomyJSON = """
        {"muscles":[{"key":"chest","name":"Chest","region":null},{"key":"back","name":"Back","region":null}],\
        "equipment":[{"key":"barbell","name":"Barbell"},{"key":"cable","name":"Cable"}],\
        "categories":["strength","cardio"],"difficulties":["beginner","intermediate","advanced"]}
        """
    }
#endif
