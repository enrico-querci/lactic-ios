import Foundation
import Testing
@testable import LacticCore

@Suite("API date decoding")
struct APIDateFormatTests {
    /// The exact string shape `lactic-api` emits since PR #46 settled its
    /// datetime format. Captured from a real response, not invented.
    @Test func decodesTheFormatTheAPIActuallySends() throws {
        let date = try #require(APIDateFormat.date(from: "2026-09-08T10:07:51.048Z"))
        let components = try Calendar(identifier: .gregorian).dateComponents(
            in: #require(TimeZone(identifier: "UTC")), from: date
        )
        #expect(components.year == 2026)
        #expect(components.month == 9)
        #expect(components.day == 8)
        #expect(components.hour == 10)
        #expect(components.minute == 7)
        #expect(components.second == 51)
    }

    @Test func acceptsATimestampWithoutFractionalSeconds() {
        #expect(APIDateFormat.date(from: "2026-09-08T10:07:51Z") != nil)
    }

    /// Ruby's `Time#to_s`, which is what every Blueprint-rendered endpoint used
    /// to emit. If it ever comes back, decoding should fail loudly here rather
    /// than silently produce a wrong date somewhere in the UI.
    @Test func rejectsTheOldRubyTimeFormat() {
        #expect(APIDateFormat.date(from: "2026-09-08 10:07:51 UTC") == nil)
    }

    @Test func rejectsNonsense() {
        #expect(APIDateFormat.date(from: "") == nil)
        #expect(APIDateFormat.date(from: "not a date") == nil)
    }

    /// ISO8601FormatStyle truncates the fraction instead of rounding, so a
    /// naive encoder loses a millisecond on about half of all timestamps.
    @Test(arguments: ["000", "001", "047", "048", "500", "998", "999"])
    func roundTripsEveryMillisecondExactly(fraction: String) throws {
        let original = "2026-09-08T10:07:51.\(fraction)Z"
        let date = try #require(APIDateFormat.date(from: original))
        #expect(APIDateFormat.string(from: date) == original)
    }

    @Test func roundTripsThroughTheSharedCoders() throws {
        struct Payload: Codable, Equatable { let startedAt: Date }
        let json = Data(#"{"startedAt":"2026-09-08T10:07:51.048Z"}"#.utf8)

        let decoded = try JSONCoding.decoder.decode(Payload.self, from: json)
        let reencoded = try JSONCoding.encoder.encode(decoded)
        let again = try JSONCoding.decoder.decode(Payload.self, from: reencoded)

        #expect(decoded == again)
        #expect(String(decoding: reencoded, as: UTF8.self).contains("2026-09-08T10:07:51.048Z"))
    }

    @Test func surfacesAReadableErrorForABadTimestamp() {
        struct Payload: Decodable { let startedAt: Date }
        let json = Data(#"{"startedAt":"2026-09-08 10:07:51 UTC"}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONCoding.decoder.decode(Payload.self, from: json)
        }
    }
}
