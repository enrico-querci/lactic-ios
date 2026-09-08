// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LacticUI",
    defaultLocalization: "en",
    // macOS is declared so `swift test` runs on the host without a
    // simulator. Without it SPM targets an ancient macOS and anything modern
    // fails to compile. iOS is the only shipping platform.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "LacticUI", targets: ["LacticUI"]),
    ],
    dependencies: [
        .package(path: "../LacticCore"),
    ],
    targets: [
        .target(
            name: "LacticUI",
            dependencies: [.product(name: "LacticCore", package: "LacticCore")],
            swiftSettings: .lactic
        ),
        .testTarget(name: "LacticUITests", dependencies: ["LacticUI"], swiftSettings: .lactic),
    ]
)

extension [SwiftSetting] {
    static var lactic: Self {
        [.swiftLanguageMode(.v6), .enableUpcomingFeature("ExistentialAny")]
    }
}
