// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StandardAppComponents",
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
            name: "StandardAppComponents"
        ),
        .testTarget(
            name: "StandardAppComponentsTests",
            dependencies: ["StandardAppComponents"]
        )
    ]
)
