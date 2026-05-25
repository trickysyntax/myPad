// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MyPadKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "MyPadKit",
            targets: ["MyPadKit"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MyPadKit",
            dependencies: [],
            path: "Sources/MyPadKit"
        ),
        .testTarget(
            name: "MyPadKitTests",
            dependencies: ["MyPadKit"],
            path: "Tests/MyPadKitTests"
        ),
    ]
)
