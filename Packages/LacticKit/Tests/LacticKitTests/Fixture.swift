import Foundation
import LacticCore
import Testing

/// Loads a response captured verbatim from a running `lactic-api`.
///
/// These are real bytes, not hand-written approximations: the whole point is to
/// catch the difference between what the API documentation implies and what it
/// actually sends. They were captured by walking the client flow with curl
/// against a `bin/rails dev:seed` database.
enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
            "missing fixture \(name).json"
        )
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try JSONCoding.decoder.decode(type, from: data(name))
    }
}
