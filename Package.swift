// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StandardAppComponents",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "StandardAppComponents",
            targets: ["StandardAppComponents"]
        )
    ],
    targets: [
        .target(
            name: "StandardAppComponents",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "StandardAppComponentsTests",
            dependencies: ["StandardAppComponents"]
        )
    ]
)
