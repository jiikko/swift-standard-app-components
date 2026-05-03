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
    dependencies: [
        // SwiftLint を SwiftPM Build Tool Plugin として組み込む。
        // `swift build` 実行時に自動で lint を走らせる目的。SwiftLint バイナリを
        // bundle しているので別途 brew install swiftlint は不要。
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.63.0")
    ],
    targets: [
        .target(
            name: "StandardAppComponents",
            resources: [
                .process("Resources")
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
        .testTarget(
            name: "StandardAppComponentsTests",
            dependencies: ["StandardAppComponents"]
        )
    ]
)
