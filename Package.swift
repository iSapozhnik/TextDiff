// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TextDiff",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TextDiffCore",
            targets: ["TextDiffCore"]
        ),
        .library(
            name: "TextDiffMacOSUI",
            targets: ["TextDiffMacOSUI"]
        ),
        .library(
            name: "TextDiff",
            targets: ["TextDiff"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            from: "1.18.9"
        )
    ],
    targets: [
        .target(
            name: "TextDiffCore",
            swiftSettings: [
                .define("TESTING", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "TextDiffMacOSUI",
            dependencies: ["TextDiffCore"],
            swiftSettings: [
                .define("TESTING", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "TextDiff",
            dependencies: [
                "TextDiffCore",
                "TextDiffMacOSUI"
            ]
        ),
        .testTarget(
            name: "TextDiffCoreTests",
            dependencies: [
                "TextDiffCore"
            ]
        ),
        .testTarget(
            name: "TextDiffMacOSUITests",
            dependencies: [
                "TextDiff",
                "TextDiffCore",
                "TextDiffMacOSUI",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ]
        ),
    ]
)
