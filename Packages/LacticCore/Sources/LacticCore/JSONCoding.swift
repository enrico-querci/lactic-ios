import Foundation

/// Shared JSON coders for every Lactic API payload.
///
/// Deliberately **no** `keyDecodingStrategy`. `.convertFromSnakeCase` also
/// rewrites the keys of dictionaries decoded as `[String: T]`, and one payload
/// field is exactly that: `Workout.volume_sets` is keyed by muscle-group
/// display name, localized, and comes straight from the database. Today none
/// of those names contain an underscore so the strategy would be harmless, but
/// the failure would be silent and locale-dependent when one eventually does.
/// Every model spells its wire names out in `CodingKeys` instead, which also
/// makes the contract readable at the point it is decoded.
public enum JSONCoding {
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = APIDateFormat.date(from: raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected an ISO 8601 timestamp, got \(raw.debugDescription)"
                )
            }
            return date
        }
        return decoder
    }()

    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(APIDateFormat.string(from: date))
        }
        return encoder
    }()
}

/// Parses the API's timestamps.
///
/// `lactic-api` emits one format everywhere — `2026-09-08T10:07:51.048Z`, ISO
/// 8601 in UTC with milliseconds — since the Blueprinter initializer that
/// settled it (lactic-api PR #46). Before that, Blueprint-rendered payloads
/// used Ruby's `Time#to_s` and Hash-rendered ones used ISO 8601, so the same
/// API spoke two dialects.
///
/// The fractionless variant is still accepted because nothing on the wire
/// guarantees a non-zero millisecond component survives every producer, and
/// `ISO8601DateFormatter` treats the two as different formats rather than one
/// optional component. This is cheap tolerance, not a workaround for a bug.
public enum APIDateFormat {
    // Format styles, not ISO8601DateFormatter: the formatter is a reference
    // type and not Sendable, so a shared static instance is a data race under
    // Swift 6's complete concurrency checking. These are Sendable values.
    private static let withFractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let withoutFractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: false)

    public static func date(from string: String) -> Date? {
        if let date = try? withFractionalSeconds.parse(string) {
            return date
        }
        return try? withoutFractionalSeconds.parse(string)
    }

    /// Always writes milliseconds, matching what the API emits.
    ///
    /// The fractional part is assembled by hand because
    /// `ISO8601FormatStyle` **truncates** it rather than rounding: a `Date`
    /// parsed from `…51.048Z` holds a binary value a hair under 51.048 and
    /// formats back as `…51.047Z`. Pre-rounding the `Date` does not help — the
    /// rounded value is the same `Double`. Truncation loses a millisecond on
    /// roughly half of all timestamps, so an encoder built on it cannot
    /// round-trip its own decoder.
    public static func string(from date: Date) -> String {
        let interval = date.timeIntervalSince1970
        var whole = interval.rounded(.down)
        var milliseconds = Int(((interval - whole) * 1000).rounded())
        if milliseconds >= 1000 {
            milliseconds -= 1000
            whole += 1
        }
        let seconds = withoutFractionalSeconds.format(Date(timeIntervalSince1970: whole))
        // Always UTC, so the style always terminates the string with "Z".
        guard seconds.hasSuffix("Z") else { return seconds }
        return seconds.dropLast() + String(format: ".%03dZ", milliseconds)
    }
}
