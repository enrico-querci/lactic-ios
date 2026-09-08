import Testing
@testable import LacticUI

@Test func versionIsSet() {
    #expect(!LacticUI.version.isEmpty)
}
