// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LacticCore",
    defaultLocalization: "en",
    // macOS is declared so `swift test` runs on the host without a
    // simulator. Without it SPM targets an ancient macOS and anything modern
    // fails to compile. iOS is the only shipping platform.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "LacticCore", targets: ["LacticCore"]),
    ],
    targets: [
        .target(name: "LacticCore", swiftSettings: .lactic),
        .testTarget(name: "LacticCoreTests", dependencies: ["LacticCore"], swiftSettings: .lactic),
    ]
)

extension [SwiftSetting] {
    /// Shared across every Lactic package: Swift 6 language mode with complete
    /// concurrency checking, matching Configs/Shared.xcconfig.
    static var lactic: Self {
        [.swiftLanguageMode(.v6), .enableUpcomingFeature("ExistentialAny")]
    }
}
