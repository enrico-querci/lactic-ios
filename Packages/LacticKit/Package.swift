// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LacticKit",
    defaultLocalization: "en",
    // macOS is declared so `swift test` runs on the host without a
    // simulator. Without it SPM targets an ancient macOS and anything modern
    // fails to compile. iOS is the only shipping platform.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "LacticKit", targets: ["LacticKit"]),
    ],
    dependencies: [
        .package(path: "../LacticCore"),
        // The only third-party dependency in the project, per AGENTS.md 6.1.
        // Sign in with Apple needs none (AuthenticationServices) and arrives at
        // the App Store gate, where guideline 4.8 makes it mandatory once
        // Google ships. See docs/ios-plan.md.
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "8.0.0"),
    ],
    targets: [
        .target(
            name: "LacticKit",
            dependencies: [
                .product(name: "LacticCore", package: "LacticCore"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
            ],
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
