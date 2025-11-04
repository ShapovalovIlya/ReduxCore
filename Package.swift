// swift-tools-version: 5.8
// swift-tools-version: 6.0
// swift-tools-version: 6.2
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
        .library(name: "ReduxSync", targets: ["ReduxSync"]),
        .library(name: "ReducerDomain", targets: ["ReducerDomain"]),
    ],
    targets: [
        .target(name: "CoWBox"),
        .target(name: "SequenceFX"),
        .target(name: "ReducerDomain"),
        .target(
            name: "ReduxSync",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "ReduxStream",
            dependencies: [
                "SequenceFX"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(name: "StoreThread"),
        .target(
            name: "ReduxCore",
            dependencies: [
                "ReduxSync",
                "ReduxStream",
                "StoreThread",
                "CoWBox",
                "SequenceFX",
                "ReducerDomain",
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(name: "ReduxCoreTests", dependencies: ["ReduxCore"]),
    ]
//,
//    swiftLanguageVersions: [
//        .v5,
//        .version("6.0")
//    ]
)
