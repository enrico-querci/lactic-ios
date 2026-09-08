import Foundation

/// Intercepts `URLSession` traffic so `APIClient` can be exercised end to end
/// without a server.
///
/// Registered on an ephemeral configuration rather than globally, so a test
/// cannot leak responses into another one.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response {
        let status: Int
        let body: Data
        let headers: [String: String]

        init(status: Int = 200, body: Data = Data("{}".utf8), headers: [String: String] = [:]) {
            self.status = status
            self.body = body
            self.headers = headers
        }

        static func json(_ string: String, status: Int = 200) -> Response {
            Response(status: status, body: Data(string.utf8))
        }
    }

    /// Shared because URLProtocol is instantiated by URLSession, which gives no
    /// hook to inject per-test state. Guarded by a lock and reset between tests.
    private static let lock = NSLock()
    private nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> Response)?
    private nonisolated(unsafe) static var recorded: [URLRequest] = []

    static func configure(_ handler: @escaping @Sendable (URLRequest) -> Response) {
        lock.withLock {
            self.handler = handler
            recorded = []
        }
    }

    static var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    static func requestCount(forPathSuffix suffix: String) -> Int {
        requests.filter { $0.url?.path.hasSuffix(suffix) == true }.count
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = Self.lock.withLock { () -> Response in
            Self.recorded.append(request)
            return Self.handler?(request) ?? Response(status: 500)
        }

        guard let url = request.url,
              let http = HTTPURLResponse(
                  url: url,
                  statusCode: response.status,
                  httpVersion: "HTTP/1.1",
                  headerFields: response.headers.merging(["Content-Type": "application/json"]) { current, _ in current }
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
