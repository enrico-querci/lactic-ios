import Foundation

/// Every failure the API can express.
///
/// There are exactly three error envelopes on the wire and they are not
/// interchangeable:
///
///   `{"error": "Not found"}`                              — most failures
///   `{"errors": ["Reps must be greater than 0"]}`         — model validation, 422
///   `{"error": "...", "code": "client_limit_reached"}`    — the coach 402
///
/// Note the singular/plural key difference: a 422 from `RecordInvalid` uses
/// `errors` with an array, while a 422 from a business rule uses `error` with a
/// string. Both are 422.
public enum APIError: Error, Sendable, Equatable {
    /// A structured failure the server described.
    case api(status: Int, messages: [String], code: String?, path: String)
    /// A response that was not JSON at all. `AuthController` does not include
    /// `ErrorHandling`, so a validation failure during first-time user creation
    /// escapes as a plain 500 with an HTML body.
    case malformedResponse(status: Int, path: String)
    case transport(URLError)
    case decoding(String, path: String)
    /// The refresh token was rejected, so the session is over.
    case sessionExpired

    public var status: Int? {
        switch self {
        case .api(let status, _, _, _), .malformedResponse(let status, _): status
        case .transport, .decoding: nil
        case .sessionExpired: 401
        }
    }

    /// A single human-readable message, joining a validation array the way the
    /// web client does.
    public var message: String {
        switch self {
        case .api(let status, let messages, _, _):
            messages.isEmpty ? "HTTP \(status)" : messages.joined(separator: ", ")
        case .malformedResponse(let status, _):
            "The server returned an unexpected response (HTTP \(status))."
        case .transport(let error):
            error.localizedDescription
        case .decoding(let detail, _):
            "Could not read the server's response: \(detail)"
        case .sessionExpired:
            "Your session has expired. Please sign in again."
        }
    }

    /// A machine-readable code, currently only `client_limit_reached` on 402.
    public var code: String? {
        if case .api(_, _, let code, _) = self {
            return code
        }
        return nil
    }

    /// 4xx is routine and expected; anything else is worth reporting.
    public var isReportable: Bool {
        switch self {
        case .api(let status, _, _, _), .malformedResponse(let status, _): !(400 ..< 500).contains(status)
        case .decoding: true
        case .transport, .sessionExpired: false
        }
    }

    /// Whether retrying unchanged could plausibly succeed. A validation failure
    /// never can, which is what stops the outbox spinning on a rejected write.
    public var isRetryable: Bool {
        switch self {
        case .api(let status, _, _, _), .malformedResponse(let status, _):
            status == 408 || status == 429 || status >= 500
        case .transport: true
        case .decoding, .sessionExpired: false
        }
    }
}

/// Decodes whichever envelope the server used.
struct APIErrorEnvelope: Decodable {
    let messages: [String]
    let code: String?

    enum CodingKeys: String, CodingKey {
        case error, errors, code
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let single = try container.decodeIfPresent(String.self, forKey: .error) {
            messages = [single]
        } else if let many = try container.decodeIfPresent([String].self, forKey: .errors) {
            messages = many
        } else {
            messages = []
        }
        code = try container.decodeIfPresent(String.self, forKey: .code)
    }
}
