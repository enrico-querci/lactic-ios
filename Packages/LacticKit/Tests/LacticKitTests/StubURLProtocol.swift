import Foundation

/// A `URLSession` whose responses are scripted, for testing `APIClient` without
/// a server.
///
/// Each instance is isolated. An earlier version kept the handler and the
/// recorded requests in statics, which worked while only one suite used it and
/// then silently cross-contaminated the moment a second one existed — Swift
/// Testing runs suites in parallel, so an auth request from one suite turned up
/// in another's assertions. Isolation is by a token carried in a header the
/// session adds to every request.
final class StubTransport: @unchecked Sendable {
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

    static let headerName = "X-Stub-Transport"

    private static let registryLock = NSLock()
    private nonisolated(unsafe) static var registry: [String: StubTransport] = [:]

    private let token = UUID().uuidString
    private let lock = NSLock()
    private var handler: @Sendable (URLRequest) -> Response
    private var recorded: [URLRequest] = []

    let session: URLSession

    init(handler: @escaping @Sendable (URLRequest) -> Response) {
        self.handler = handler

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [Self.headerName: token]
        session = URLSession(configuration: configuration)

        Self.registryLock.withLock { Self.registry[token] = self }
    }

    deinit {
        let token = token
        Self.registryLock.withLock { Self.registry[token] = nil }
    }

    /// Replaces the scripted responses mid-test.
    func respond(with handler: @escaping @Sendable (URLRequest) -> Response) {
        lock.withLock { self.handler = handler }
    }

    var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    var paths: [String] {
        requests.compactMap(\.url?.path)
    }

    func requestCount(forPathSuffix suffix: String) -> Int {
        paths.filter { $0.hasSuffix(suffix) }.count
    }

    static func transport(for request: URLRequest) -> StubTransport? {
        guard let token = request.value(forHTTPHeaderField: headerName) else { return nil }
        return registryLock.withLock { registry[token] }
    }

    fileprivate func handle(_ request: URLRequest) -> Response {
        lock.withLock {
            recorded.append(request)
            return handler(request)
        }
    }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        StubTransport.transport(for: request) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let transport = StubTransport.transport(for: request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let response = transport.handle(request)

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
