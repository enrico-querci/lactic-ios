import Foundation

/// Decodes a `Decimal` that the API sends as a JSON **string**, and writes it
/// back as a JSON **number**.
///
/// `set_logs.weight_kg` and `workout_exercises.weight` are Postgres `decimal`
/// columns. Rails serializes `BigDecimal#as_json` via `to_s`, so a read returns
/// `"70.0"` while a write expects `70.0`. The asymmetry is real and asserted in
/// the API's own suite (`set_logs_controller_test.rb` expects `"70.0"`), and
/// `lactic-web` types the same field as `number`, which is simply wrong — it
/// gets away with it because JavaScript coerces on use.
///
/// A number is accepted on read too, so the models keep working if the API ever
/// stops stringifying decimals.
@propertyWrapper
public struct LenientDecimal: Codable, Hashable, Sendable {
    public var wrappedValue: Decimal

    public init(wrappedValue: Decimal) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = try LenientDecimalParsing.decimal(from: container)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

/// The nullable form. `weight` is optional on `workout_exercises`.
@propertyWrapper
public struct LenientDecimalOptional: Codable, Hashable, Sendable {
    public var wrappedValue: Decimal?

    public init(wrappedValue: Decimal?) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = container.decodeNil() ? nil : try LenientDecimalParsing.decimal(from: container)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

public extension KeyedDecodingContainer {
    /// Lets `@LenientDecimalOptional` survive a key that is absent rather than
    /// merely null. Without this, `Decodable` synthesis demands the key.
    func decode(_ type: LenientDecimalOptional.Type, forKey key: Key) throws -> LenientDecimalOptional {
        try decodeIfPresent(type, forKey: key) ?? LenientDecimalOptional(wrappedValue: nil)
    }
}

enum LenientDecimalParsing {
    static func decimal(from container: any SingleValueDecodingContainer) throws -> Decimal {
        if let string = try? container.decode(String.self) {
            // Decimal(string:) is locale-sensitive; the wire is always a plain
            // dot-separated decimal, so parse it as such.
            guard let value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected a decimal string, got \(string.debugDescription)"
                )
            }
            return value
        }
        return try container.decode(Decimal.self)
    }
}
