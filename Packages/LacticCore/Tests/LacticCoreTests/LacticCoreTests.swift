import Testing
@testable import LacticCore

@Test func versionIsSet() {
    #expect(!LacticCore.version.isEmpty)
}
