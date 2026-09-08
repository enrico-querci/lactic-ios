// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LacticKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "LacticKit", targets: ["LacticKit"]),
    ],
    dependencies: [
        .package(path: "../LacticCore"),
        // GoogleSignIn-iOS is added here at order-of-work step 8. Sign in with
        // Apple needs no dependency (AuthenticationServices) and arrives at the
        // App Store gate, since guideline 4.8 makes it mandatory once Google
        // ships. See docs/ios-plan.md.
    ],
    targets: [
        .target(
            name: "LacticKit",
            dependencies: [.product(name: "LacticCore", package: "LacticCore")],
            swiftSettings: .lactic
        ),
        .testTarget(
            name: "LacticKitTests",
            dependencies: ["LacticKit"],
            resources: [.copy("Fixtures")],
            swiftSettings: .lactic
        ),
    ]
)

extension [SwiftSetting] {
    static var lactic: Self {
        [.swiftLanguageMode(.v6), .enableUpcomingFeature("ExistentialAny")]
    }
}
