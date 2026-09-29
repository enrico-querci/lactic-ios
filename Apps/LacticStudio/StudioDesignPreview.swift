#if DEBUG
    import Foundation
    import LacticKit
    import LacticUI
    import SwiftUI

    /// Runs the production Studio shell against deterministic in-memory HTTP
    /// fixtures, so no account or live API is needed for visual review.
    @MainActor
    struct StudioDesignPreview: View {
        @State private var model: ClientListModel
        private let client: APIClient

        init() {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [StudioPreviewProtocol.self]
            let client = APIClient(
                configuration: .localDevelopment(locale: { "en" }),
                session: URLSession(configuration: configuration)
            )
            self.client = client
            _model = State(initialValue: ClientListModel(client: client))
        }

        var body: some View {
            StudioShell(
                client: client,
                coachName: "John Coach",
                coachEmail: "john@example.com",
                roster: model,
                signOut: {},
                deleteAccount: {}
            )
            .task { await model.load() }
        }
    }

    private final class StudioPreviewProtocol: URLProtocol, @unchecked Sendable {
        override class func canInit(with _: URLRequest) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            // `--studio-preview-latency` answers after 300 ms, like a real
            // network. Instant fixtures hid a load loop that only a round trip
            // long enough to be interrupted could expose.
            if ProcessInfo.processInfo.arguments.contains("--studio-preview-latency"), !isDelayed {
                isDelayed = true
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { self.startLoading() }
                return
            }
            guard let url = request.url else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }

            let payload = Self.payload(for: request)
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: payload.status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(payload.body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
        private nonisolated(unsafe) var isDelayed = false

        private static func payload(for request: URLRequest) -> (status: Int, body: String) {
            let path = request.url?.path ?? ""
            let method = request.httpMethod ?? "GET"
            let isFull = ProcessInfo.processInfo.arguments.contains("--studio-plan-full")

            if method == "POST", path.hasSuffix("/resend") {
                return (200, invitationJSON(id: 21, email: "marco@example.com"))
            }
            if method == "POST", path.hasSuffix("/client_invitations") {
                if isFull {
                    return (402, #"{"error":"You've reached your plan's client limit","code":"client_limit_reached"}"#)
                }
                return (201, invitationJSON(id: 99, email: "new.client@example.com"))
            }
            if method == "DELETE" {
                return (204, "")
            }
            if let response = StudioPreviewFixtures.response(method: method, path: path, request: request) {
                return response
            }
            if path.hasSuffix("/clients") {
                return (200, clientsJSON)
            }
            if path.hasSuffix("/client_invitations") {
                return (200, invitationsJSON)
            }
            if path.hasSuffix("/subscription") {
                let limit = isFull ? 4 : 6
                return (200, subscriptionJSON(used: 4, limit: limit))
            }
            return (404, #"{"error":"Not found"}"#)
        }

        private static let clientsJSON = """
        [
          {"id":7,"avatar_url":null,"email":"alice@example.com","name":"Alice Bianchi","role":"client"},
          {"id":8,"avatar_url":null,"email":"dario@example.com","name":"Dario Romano","role":"client"}
        ]
        """

        private static let invitationsJSON = """
        [
          \(invitationJSON(id: 21, email: "marco@example.com")),
          \(invitationJSON(id: 22, email: "sara@example.com"))
        ]
        """

        private static func invitationJSON(id: Int, email: String) -> String {
            """
            {"id":\(id),"email":"\(email)","status":"pending",\
            "expires_at":"2026-09-19T10:00:00.000Z","sent_at":"2026-09-12T10:00:00.000Z",\
            "created_at":"2026-09-12T10:00:00.000Z","coach_name":"John Coach"}
            """
        }

        private static func subscriptionJSON(used: Int, limit: Int?) -> String {
            let limit = limit.map(String.init) ?? "null"
            return """
            {"plan":"pro","client_limit":\(limit),"client_slots_used":\(used),\
            "expires_at":"2026-10-29T10:00:00.000Z","auto_renew":true,"billing_issue":false}
            """
        }
    }

    #Preview("Studio — clients") {
        StudioDesignPreview()
            .environment(StudioEnvironment())
            .tint(LacticColor.accent)
    }
#endif
