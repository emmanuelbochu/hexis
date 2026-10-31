// swift-tools-version: 6.2
import PackageDescription

// The app's pure logic (Models + Services + the workout view model, symlinked by ../logic_tests.sh) compiled for macOS
// with the app's concurrency settings (main actor by default), so its rules and real-life scenarios can be tested.
let settings: [SwiftSetting] = [
    .swiftLanguageMode(.v5), .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"), .enableUpcomingFeature("InferIsolatedConformances"),
]
let package = Package(
    name: "HexisLogic",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "HexisLogic", swiftSettings: settings),
        .testTarget(name: "LogicTests", dependencies: ["HexisLogic"], swiftSettings: settings),
    ]
)
