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
        // README に載せるスクショを `ImageRenderer` で生成する開発者向けユーティリティ。
        // `swift run ScreenshotGenerator` で `docs/images/*.png` を再生成する。
        // products に含めないため SPM consumer (各 macOS アプリ) からは見えない。
        .executableTarget(
            name: "ScreenshotGenerator",
            dependencies: ["StandardAppComponents"],
            path: "Tools/ScreenshotGenerator"
        ),
        .testTarget(
            name: "StandardAppComponentsTests",
            dependencies: ["StandardAppComponents"]
        )
    ]
)
