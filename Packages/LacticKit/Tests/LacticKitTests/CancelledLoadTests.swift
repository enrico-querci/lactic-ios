import Foundation
import Testing
@testable import LacticKit

@MainActor
private func makeClient(
    _ handler: @escaping @Sendable (URLRequest) -> StubTransport.Response
) -> (APIClient, StubTransport) {
    let transport = StubTransport(handler: handler)
    let client = APIClient(
        configuration: APIConfiguration(baseURL: URL(string: "https://api.test")!) { "en" },
        session: transport.session
    )
    return (client, transport)
}

@MainActor
@Suite("Cancelled loads", .serialized)
struct CancelledLoadTests {
    /// A load abandoned because its view left the screen is not a failure.
    /// Treating it as one — or letting it reset state — is what let the
    /// Assignments screen restart its load in a loop on iPhone.
    @Test func aCancelledLoadLeavesNoFailureAndTheNextOneWorks() async {
        let (client, transport) = makeClient { _ in .failing(.cancelled) }
        let model = AssignmentListModel(client: client)

        await model.load()

        #expect(model.failure == nil)
        #expect(model.hasLoaded == false)
        #expect(model.isLoading == false)

        transport.respond { _ in .json("[]") }
        await model.load()

        #expect(model.hasLoaded)
        #expect(model.failure == nil)
    }

    @Test func aRealOutageIsStillReported() async {
        let (client, _) = makeClient { _ in .failing(.notConnectedToInternet) }
        let model = ProgramListModel(client: client)

        await model.load()

        #expect(model.failure == .offline)
    }

    @Test func recognisesEveryShapeOfCancellation() {
        #expect(CancellationError().isCancellation)
        #expect(URLError(.cancelled).isCancellation)
        #expect(APIError.transport(URLError(.cancelled)).isCancellation)
        #expect(!APIError.transport(URLError(.timedOut)).isCancellation)
    }
}
