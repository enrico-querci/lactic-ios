import Testing
@testable import Lactic

/// The app target's own tests. The training derivations moved to
/// `LacticKitTests` along with the arithmetic they cover.
@Test func appModuleLoads() {
    #expect(Bool(true))
}
