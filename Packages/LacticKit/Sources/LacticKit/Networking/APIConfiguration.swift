import Foundation

public struct APIConfiguration: Sendable {
    public let baseURL: URL
    /// Sent as `Accept-Language` on every request. The app's own choice, not
    /// the device's: the API resolves the locale from this header, and an
    /// in-app language switcher has to win over the system setting.
    public let locale: @Sendable () -> String

    public init(baseURL: URL, locale: @escaping @Sendable () -> String) {
        self.baseURL = baseURL
        self.locale = locale
    }

    /// `http://localhost:3000`, reachable because Info.plist sets
    /// `NSAllowsLocalNetworking`.
    public static func localDevelopment(locale: @escaping @Sendable () -> String) -> APIConfiguration {
        APIConfiguration(baseURL: URL(string: "http://localhost:3000")!, locale: locale)
    }

    public static func production(locale: @escaping @Sendable () -> String) -> APIConfiguration {
        APIConfiguration(baseURL: URL(string: "https://lactic-api-production.up.railway.app")!, locale: locale)
    }

    func url(for endpoint: Endpoint) -> URL? {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/v1" + endpoint.path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = endpoint.query.isEmpty ? nil : endpoint.query
        return components?.url
    }

    /// Resolves an `Exercise.animationPath`, which arrives already rooted at
    /// `/api/v1` and so must not be joined onto the versioned base a second
    /// time. The result still needs an `Authorization` header — the endpoint is
    /// authenticated and proxies bytes rather than redirecting.
    public func animationURL(path: String) -> URL? {
        URL(string: path, relativeTo: baseURL)?.absoluteURL
    }
}
