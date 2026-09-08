import Foundation
import Testing
@testable import LacticCore

@Suite("Presentation formatting")
struct FormattersTests {
    /// Matches lactic-web's formatDuration so both clients agree.
    @Test(arguments: [
        (0, "0min"), (59, "0min"), (60, "1min"), (2700, "45min"),
        (3600, "1h 0min"), (3900, "1h 5min"), (7500, "2h 5min"),
    ])
    func formatsDuration(seconds: Int, expected: String) {
        #expect(Formatters.duration(seconds: seconds) == expected)
    }

    @Test func clampsNegativeDurations() {
        #expect(Formatters.duration(seconds: -10) == "0min")
    }

    @Test func trimsTrailingZeroesFromWeights() throws {
        #expect(Formatters.weight(Decimal(70), locale: .english) == "70")
        #expect(try Formatters.weight(#require(Decimal(string: "72.5")), locale: .english) == "72.5")
    }

    /// The API models a week as days 1-7 starting Monday, which is not how
    /// Gregorian weekday symbols are indexed.
    @Test func mapsDayOneToMonday() {
        #expect(Formatters.weekdayName(day: 1, locale: .english).hasPrefix("Mon"))
        #expect(Formatters.weekdayName(day: 7, locale: .english).hasPrefix("Sun"))
        #expect(Formatters.weekdayName(day: 0, locale: .english).isEmpty)
        #expect(Formatters.weekdayName(day: 8, locale: .english).isEmpty)
    }

    @Test func supportsExactlyTheLocalesTheAPIServes() {
        #expect(AppLocale.allCases.map(\.rawValue).sorted() == ["en", "it"])
    }
}
