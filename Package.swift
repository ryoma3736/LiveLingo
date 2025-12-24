// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LiveLingo",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LiveLingo",
            targets: ["LiveLingo"]
        ),
    ],
    dependencies: [
        // Dependency Injection
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        // Async utilities
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        // Collections
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "LiveLingo",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Collections", package: "swift-collections"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "LiveLingoTests",
            dependencies: ["LiveLingo"],
            path: "Tests/UnitTests"
        ),
        .testTarget(
            name: "LiveLingoIntegrationTests",
            dependencies: ["LiveLingo"],
            path: "Tests/IntegrationTests"
        ),
    ]
)
