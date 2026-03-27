// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DeskBoard",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "DeskBoard",
            targets: ["DeskBoard"]
        )
    ],
    dependencies: [
        // Secure keychain access wrapper
        .package(
            url: "https://github.com/kishikawakatsumi/KeychainAccess",
            from: "4.2.2"
        )
    ],
    targets: [
        .target(
            name: "DeskBoard",
            dependencies: [
                "KeychainAccess"
            ],
            path: "Sources/DeskBoard",
            resources: [
                .process("../../Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ],
            linkerSettings: [
                .linkedFramework("MultipeerConnectivity")
            ]
        ),
        .testTarget(
            name: "DeskBoardTests",
            dependencies: ["DeskBoard"],
            path: "Tests/DeskBoardTests"
        )
    ]
)