import Foundation
import LacticCore

/// Supplies and rotates the tokens an authenticated request needs.
///
/// Separated from `APIClient` so the transport can be tested without a
/// keychain, and so the session store owns persistence exclusively.
public protocol TokenProviding: AnyObject, Sendable {
    func currentAccessToken() async -> String?
    /// Performs one refresh and returns the new access token, or nil if the
    /// session is over. Implementations must coalesce concurrent callers: the
    /// API destroys the old refresh-token row on use, so two racing refreshes
    /// mean one of them fails permanently.
    func refreshAccessToken() async throws -> String?
    func clearSession() async
}

public actor APIClient {
    private let configuration: APIConfiguration
    private let session: URLSession
    private weak var tokenProvider: (any TokenProviding)?

    public init(configuration: APIConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func setTokenProvider(_ provider: any TokenProviding) {
        tokenProvider = provider
    }

    // MARK: - Requests

    @discardableResult
    public func send<Response: Decodable & Sendable>(
        _ endpoint: Endpoint,
        as _: Response.Type = Response.self
    ) async throws -> Response {
        let (data, _) = try await perform(endpoint)
        return try decode(Response.self, from: data, path: endpoint.path)
    }

    /// For `DELETE` and anything else answering 204 with an empty body.
    public func sendIgnoringResponse(_ endpoint: Endpoint) async throws {
        _ = try await perform(endpoint)
    }

    /// Reads the four `X-…` pagination headers alongside the bare array body.
    public func sendPaged<Element: Decodable & Sendable>(
        _ endpoint: Endpoint,
        of _: Element.Type = Element.self
    ) async throws -> Page<Element> {
        let (data, response) = try await perform(endpoint)
        let items = try decode([Element].self, from: data, path: endpoint.path)
        return Page(items: items, headers: response.allHeaderFields)
    }

    /// Fetches raw bytes, for the authenticated animation proxy.
    public func data(for endpoint: Endpoint) async throws -> Data {
        let (data, _) = try await perform(endpoint)
        return data
    }

    // MARK: - Transport

    private func perform(_ endpoint: Endpoint) async throws -> (Data, HTTPURLResponse) {
        let accessToken = endpoint.requiresAuthentication ? await tokenProvider?.currentAccessToken() : nil
        let (data, response) = try await execute(endpoint, accessToken: accessToken)

        guard response.statusCode == 401, endpoint.requiresAuthentication else {
            return try validate(data: data, response: response, path: endpoint.path)
        }

        // One refresh, one replay, then give up — matching the web client. Not
        // a loop: if the replay also 401s, the session is genuinely over.
        guard let tokenProvider else { throw APIError.sessionExpired }

        let refreshed = try? await tokenProvider.refreshAccessToken()
        guard let refreshed else {
            await tokenProvider.clearSession()
            throw APIError.sessionExpired
        }

        let (retryData, retryResponse) = try await execute(endpoint, accessToken: refreshed)
        if retryResponse.statusCode == 401 {
            await tokenProvider.clearSession()
            throw APIError.sessionExpired
        }
        return try validate(data: retryData, response: retryResponse, path: endpoint.path)
    }

    private func execute(_ endpoint: Endpoint, accessToken: String?) async throws -> (Data, HTTPURLResponse) {
        guard let url = configuration.url(for: endpoint) else {
            throw APIError.decoding("Could not build a URL", path: endpoint.path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(configuration.locale(), forHTTPHeaderField: "Accept-Language")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.malformedResponse(status: 0, path: endpoint.path)
            }
            return (data, http)
        } catch let error as URLError {
            throw APIError.transport(error)
        }
    }

    private func validate(
        data: Data, response: HTTPURLResponse, path: String
    ) throws -> (Data, HTTPURLResponse) {
        guard !(200 ..< 300).contains(response.statusCode) else { return (data, response) }

        guard let envelope = try? JSONCoding.decoder.decode(APIErrorEnvelope.self, from: data) else {
            AppLog.network.error("Non-JSON error body from \(path, privacy: .public) (\(response.statusCode))")
            throw APIError.malformedResponse(status: response.statusCode, path: path)
        }
        throw APIError.api(
            status: response.statusCode,
            messages: envelope.messages,
            code: envelope.code,
            path: path
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data, path: String) throws -> T {
        // 204 and an empty body decode as an empty JSON object where the caller
        // expects nothing meaningful.
        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }
        do {
            return try JSONCoding.decoder.decode(type, from: data)
        } catch {
            AppLog.network.error("Decoding \(String(describing: type)) from \(path, privacy: .public) failed")
            throw APIError.decoding(String(describing: error), path: path)
        }
    }
}

/// Stands in for a 204.
public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}
