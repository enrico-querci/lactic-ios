import Foundation

/// The locales the API can serve. `ExerciseTranslation::LOCALES` is `["en",
/// "it"]` and anything else in `Accept-Language` is ignored, not honoured, so
/// this is a closed set rather than a passthrough of the device's language.
public enum AppLocale: String, CaseIterable, Codable, Sendable {
    case english = "en"
    case italian = "it"

    /// Chosen from the device's preferred languages, defaulting to English —
    /// mirroring `lactic-web`'s `navigator.language` check.
    public static var deviceDefault: AppLocale {
        for language in Locale.preferredLanguages {
            if language.lowercased().hasPrefix("it") {
                return .italian
            }
            if language.lowercased().hasPrefix("en") {
                return .english
            }
        }
        return .english
    }

    /// What to send in `Accept-Language`.
    public var headerValue: String {
        rawValue
    }

    public var foundationLocale: Locale {
        switch self {
        case .english: Locale(identifier: "en_US")
        case .italian: Locale(identifier: "it_IT")
        }
    }
}

/// Presentation helpers mirroring `lactic-web/lib/utils/format.ts`, so the two
/// clients render the same values the same way.
public enum Formatters {
    public static func date(_ date: Date, locale: AppLocale) -> String {
        date.formatted(.dateTime.year().month(.abbreviated).day().locale(locale.foundationLocale))
    }

    public static func dateTime(_ date: Date, locale: AppLocale) -> String {
        date.formatted(
            .dateTime.year().month(.abbreviated).day()
                .hour(.twoDigits(amPM: .abbreviated)).minute(.twoDigits)
                .locale(locale.foundationLocale)
        )
    }

    /// `"45min"` under an hour, `"1h 5min"` above. The web leaves the units
    /// untranslated on purpose and this matches it.
    public static func duration(from start: Date, to end: Date) -> String {
        duration(seconds: Int(end.timeIntervalSince(start)))
    }

    public static func duration(seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        guard minutes >= 60 else { return "\(minutes)min" }
        return "\(minutes / 60)h \(minutes % 60)min"
    }

    /// Trims a decimal for display: `70` not `70.00`, but `72.5` intact.
    public static func weight(_ value: Decimal, locale: AppLocale) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 2)).locale(locale.foundationLocale))
    }

    /// Day 1-7 as a short weekday name. The API models a programme week as
    /// days 1-7 rather than real dates, so this is a label, not a calendar
    /// lookup.
    public static func weekdayName(day: Int, locale: AppLocale) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale.foundationLocale
        let symbols = calendar.shortStandaloneWeekdaySymbols
        // Gregorian symbols start on Sunday; the API's day 1 is Monday.
        guard (1 ... 7).contains(day), symbols.count == 7 else { return "" }
        return symbols[day % 7].capitalized(with: locale.foundationLocale)
    }
}
