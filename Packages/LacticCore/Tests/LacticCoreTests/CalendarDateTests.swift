import Foundation
import Testing
@testable import LacticCore

@Suite("Calendar dates")
struct CalendarDateTests {
    @Test func parsesTheAPIsDateOnlyFormat() throws {
        let date = try #require(CalendarDate("2026-09-01"))
        #expect(date.year == 2026)
        #expect(date.month == 9)
        #expect(date.day == 1)
        #expect(date.description == "2026-09-01")
    }

    @Test func roundTripsThroughJSON() throws {
        struct Payload: Codable, Equatable { let startDate: CalendarDate }
        let json = Data(#"{"startDate":"2026-09-01"}"#.utf8)
        let decoded = try JSONCoding.decoder.decode(Payload.self, from: json)
        #expect(decoded.startDate == CalendarDate(year: 2026, month: 9, day: 1))

        let reencoded = try JSONCoding.encoder.encode(decoded)
        #expect(String(decoding: reencoded, as: UTF8.self) == #"{"startDate":"2026-09-01"}"#)
    }

    /// A start date must not be parsed as a timestamp: attaching a zone would
    /// shift "starts 1 September" to 31 August for anyone west of UTC.
    @Test func isNotATimestamp() {
        #expect(CalendarDate("2026-09-01T00:00:00.000Z") == nil)
    }

    @Test func rejectsMalformedInput() {
        #expect(CalendarDate("2026-09") == nil)
        #expect(CalendarDate("2026-13-01") == nil)
        #expect(CalendarDate("not-a-date") == nil)
        #expect(CalendarDate("") == nil)
    }

    @Test func ordersChronologically() throws {
        let earlier = try #require(CalendarDate("2026-09-01"))
        let later = try #require(CalendarDate("2026-10-01"))
        #expect(earlier < later)
        #expect([later, earlier].sorted() == [earlier, later])
    }
}
