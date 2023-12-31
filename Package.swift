// swift-tools-version: 5.7.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReduxCore",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_13)
    ],
    products: [
        .library(name: "ReduxCore", targets: ["ReduxCore"]),
    ],
    targets: [
        .target(name: "ReduxCore"),
        .testTarget(name: "ReduxCoreTests", dependencies: ["ReduxCore"]),
    ]
)
