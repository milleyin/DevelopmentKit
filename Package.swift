// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DevelopmentKit",
    platforms: [
        .iOS(.v16) // 限制最低支持 iOS 16
    ],
    products: [
        .library(
            name: "DevelopmentKit",
            targets: ["DevelopmentKit"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DevelopmentKit",
            dependencies: [],
            path: "Sources/DevelopmentKit"
        ),
        .testTarget(
            name: "DevelopmentKitTests",
            dependencies: ["DevelopmentKit"],
            path: "Tests"
        ),
    ]
)
