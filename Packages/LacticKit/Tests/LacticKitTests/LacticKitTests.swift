import Testing
@testable import LacticKit

@Test func versionIsSet() {
    #expect(!LacticKit.version.isEmpty)
}
