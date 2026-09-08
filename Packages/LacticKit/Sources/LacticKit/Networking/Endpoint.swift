import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// One API call, described declaratively.
public struct Endpoint: Sendable {
    public let method: HTTPMethod
    /// Relative to `/api/v1`, with a leading slash.
    public let path: String
    public let query: [URLQueryItem]
    public let body: Data?
    /// Endpoints that must not carry an `Authorization` header, and must not
    /// trigger a token refresh on 401: the auth routes themselves, and the
    /// public invitation lookup.
    public let requiresAuthentication: Bool

    public init(
        method: HTTPMethod = .get,
        path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        requiresAuthentication: Bool = true
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
        self.requiresAuthentication = requiresAuthentication
    }
}

/// Wraps a payload in the root key Rails expects.
///
/// `ParamsWrapper` is switched off in the API (no `wrap_parameters.rb`, and the
/// default `format` is empty), so `params.require(:set_log)` genuinely needs
/// `{"set_log": {...}}` on the wire. The exceptions that take top-level params
/// are the auth routes, `coach/client_invitations#create`,
/// `coach/workout_templates#create`/`#apply` and `coach/workouts#duplicate`.
struct RailsWrapped<Payload: Encodable>: Encodable {
    let key: String
    let payload: Payload

    struct DynamicKey: CodingKey {
        let stringValue: String
        var intValue: Int? {
            nil
        }

        /// The failable initialisers exist only to satisfy `CodingKey`. A root
        /// key is always valid, so construction goes through this one and never
        /// needs unwrapping.
        init(_ stringValue: String) {
            self.stringValue = stringValue
        }

        init?(stringValue: String) {
            self.init(stringValue)
        }

        init?(intValue _: Int) {
            nil
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try container.encode(payload, forKey: DynamicKey(key))
    }
}
