import Foundation
import Testing
@testable import LacticCore

/// `weight_kg` and `weight` are Postgres decimals that Rails serializes with
/// `BigDecimal#to_s`, so a read is a JSON string and a write is a JSON number.
@Suite("Decimal string handling")
struct LenientDecimalTests {
    private struct SetLogLike: Codable, Equatable {
        @LenientDecimal var weightKg: Decimal
    }

    private struct WorkoutExerciseLike: Codable, Equatable {
        @LenientDecimalOptional var weight: Decimal?
    }

    @Test func decodesTheStringTheAPIActuallySends() throws {
        let decoded = try JSONCoding.decoder.decode(SetLogLike.self, from: Data(#"{"weightKg":"70.0"}"#.utf8))
        #expect(decoded.weightKg == Decimal(70))
    }

    @Test func keepsFractionalPrecision() throws {
        let decoded = try JSONCoding.decoder.decode(SetLogLike.self, from: Data(#"{"weightKg":"72.5"}"#.utf8))
        #expect(decoded.weightKg == Decimal(string: "72.5"))
    }

    /// Tolerated so the models keep working if the API stops stringifying.
    @Test func alsoDecodesAPlainNumber() throws {
        let decoded = try JSONCoding.decoder.decode(SetLogLike.self, from: Data(#"{"weightKg":70.0}"#.utf8))
        #expect(decoded.weightKg == Decimal(70))
    }

    /// The asymmetry that matters: reads are strings, writes must be numbers,
    /// because the API's strong params feed a numeric column.
    @Test func encodesAsANumberNotAString() throws {
        let encoded = try JSONCoding.encoder.encode(SetLogLike(weightKg: #require(Decimal(string: "72.5"))))
        let json = String(decoding: encoded, as: UTF8.self)
        #expect(json.contains("72.5"))
        #expect(!json.contains("\"72.5\""))
    }

    @Test func decodesAnExplicitNull() throws {
        let decoded = try JSONCoding.decoder.decode(WorkoutExerciseLike.self, from: Data(#"{"weight":null}"#.utf8))
        #expect(decoded.weight == nil)
    }

    /// A missing key is not the same as a null one, and Decodable synthesis
    /// demands the key unless the container extension handles it.
    @Test func decodesAnAbsentKey() throws {
        let decoded = try JSONCoding.decoder.decode(WorkoutExerciseLike.self, from: Data(#"{}"#.utf8))
        #expect(decoded.weight == nil)
    }

    @Test func decodesAnOptionalPresentAsAString() throws {
        let decoded = try JSONCoding.decoder.decode(WorkoutExerciseLike.self, from: Data(#"{"weight":"40.0"}"#.utf8))
        #expect(decoded.weight == Decimal(40))
    }

    @Test func rejectsAStringThatIsNotADecimal() {
        #expect(throws: DecodingError.self) {
            try JSONCoding.decoder.decode(SetLogLike.self, from: Data(#"{"weightKg":"heavy"}"#.utf8))
        }
    }
}
