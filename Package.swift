// swift-tools-version: 5.7.1
// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReduxCore",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "ReduxCore", targets: ["ReduxCore"]),
        .library(name: "ReduxStream", targets: ["ReduxStream"]),
        .library(name: "ReduxSync", targets: ["ReduxSync"])
    ],
    targets: [
        .target(name: "ReduxSync"),
        .target(name: "ReduxStream"),
        .target(name: "StoreThread"),
        .target(
            name: "ReduxCore",
            dependencies: [
                "ReduxSync",
                "ReduxStream",
                "StoreThread",
            ]
        ),
        .testTarget(name: "ReduxCoreTests", dependencies: ["ReduxCore"]),
    ]
)
