import Foundation

/// A date with no time component, as `"2026-09-01"`.
///
/// `program_assignments.start_date` is a Postgres `date`. It is not a timestamp
/// and must not become one: turning it into a `Date` would attach a time and a
/// zone, and a programme "starting 1 September" would read as 31 August for
/// anyone west of UTC.
public struct CalendarDate: Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init?(_ string: String) {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1 ... 12).contains(month), (1 ... 31).contains(day)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let parsed = CalendarDate(raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a YYYY-MM-DD date, got \(raw.debugDescription)"
            )
        }
        self = parsed
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var dateComponents: DateComponents {
        DateComponents(year: year, month: month, day: day)
    }

    /// Resolved in the given calendar, defaulting to the user's own. A plain
    /// date only becomes an instant once someone picks a zone, so the caller
    /// makes that choice explicitly.
    public func date(in calendar: Calendar = .current) -> Date? {
        calendar.date(from: dateComponents)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
