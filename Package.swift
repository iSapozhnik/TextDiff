// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TextDiff",
    platforms: [
        .macOS(.v14),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "TextDiffCore",
            targets: ["TextDiffCore"]
        ),
        .library(
            name: "TextDiffUICommon",
            targets: ["TextDiffUICommon"]
        ),
        .library(
            name: "TextDiffMacOSUI",
            targets: ["TextDiffMacOSUI"]
        ),
        .library(
            name: "TextDiffIOSUI",
            targets: ["TextDiffIOSUI"]
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
            name: "TextDiffUICommon",
            dependencies: ["TextDiffCore"],
            swiftSettings: [
                .define("TESTING", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "TextDiffMacOSUI",
            dependencies: [
                "TextDiffCore",
                "TextDiffUICommon"
            ],
            swiftSettings: [
                .define("TESTING", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "TextDiffIOSUI",
            dependencies: [
                "TextDiffCore",
                "TextDiffUICommon"
            ],
            swiftSettings: [
                .define("TESTING", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "TextDiff",
            dependencies: [
                "TextDiffCore",
                "TextDiffUICommon",
                .target(name: "TextDiffMacOSUI", condition: .when(platforms: [.macOS])),
                .target(name: "TextDiffIOSUI", condition: .when(platforms: [.iOS]))
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
                "TextDiffUICommon",
                "TextDiffMacOSUI",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ]
        ),
    ]
)
