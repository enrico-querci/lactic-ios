import Foundation
import LacticCore
import Testing
@testable import LacticKit

/// The API has three error envelopes and they are not interchangeable.
@Suite("Error envelopes")
struct APIErrorTests {
    @Test func decodesTheSingularErrorKey() throws {
        let envelope = try JSONCoding.decoder.decode(
            APIErrorEnvelope.self, from: Fixture.data("error_not_found")
        )
        #expect(envelope.messages == ["Not found"])
        #expect(envelope.code == nil)
    }

    @Test func decodesUnauthorized() throws {
        let envelope = try JSONCoding.decoder.decode(
            APIErrorEnvelope.self, from: Fixture.data("error_unauthorized")
        )
        #expect(envelope.messages == ["Unauthorized"])
    }

    /// A model validation failure uses the *plural* key with an array, while a
    /// business-rule failure at the same 422 status uses the singular one.
    @Test func decodesThePluralErrorsArray() throws {
        let envelope = try JSONCoding.decoder.decode(
            APIErrorEnvelope.self, from: Fixture.data("error_validation")
        )
        #expect(envelope.messages == ["Reps must be greater than 0"])
    }

    @Test func decodesTheCoachLimitCode() throws {
        let json = Data(#"{"error":"You've reached your plan's client limit","code":"client_limit_reached"}"#.utf8)
        let envelope = try JSONCoding.decoder.decode(APIErrorEnvelope.self, from: json)
        #expect(envelope.code == "client_limit_reached")
    }

    @Test func joinsMultipleValidationMessages() {
        let error = APIError.api(
            status: 422,
            messages: ["Reps must be greater than 0", "Position has already been taken"],
            code: nil,
            path: "/client/set_logs"
        )
        #expect(error.message == "Reps must be greater than 0, Position has already been taken")
    }

    /// A rejected write must not be retried forever by the outbox.
    @Test func treatsValidationFailuresAsPermanent() {
        let invalid = APIError.api(status: 422, messages: ["Reps must be greater than 0"], code: nil, path: "/x")
        #expect(!invalid.isRetryable)

        let taken = APIError.api(status: 422, messages: ["Position has already been taken"], code: nil, path: "/x")
        #expect(!taken.isRetryable)
    }

    @Test func treatsServerAndTransportFailuresAsRetryable() {
        #expect(APIError.api(status: 500, messages: ["boom"], code: nil, path: "/x").isRetryable)
        #expect(APIError.api(status: 503, messages: ["later"], code: nil, path: "/x").isRetryable)
        #expect(APIError.transport(URLError(.notConnectedToInternet)).isRetryable)
    }

    /// Routine 4xx should not page anyone; 5xx and decoding failures should.
    @Test func reportsOnlyWhatIsWorthReporting() {
        #expect(!APIError.api(status: 404, messages: ["Not found"], code: nil, path: "/x").isReportable)
        #expect(APIError.api(status: 500, messages: ["boom"], code: nil, path: "/x").isReportable)
        #expect(APIError.decoding("bad", path: "/x").isReportable)
        #expect(!APIError.sessionExpired.isReportable)
    }
}
