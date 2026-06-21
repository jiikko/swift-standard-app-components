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
        ),
        // UI 非依存のロギング機構 (dual-sink: os.Logger + DEBUG NSLog ミラー + 色 + privacy)。
        // `StandardAppComponents` (UI 主体) とは別 product にすることで、UI 依存を背負えない
        // レイヤー (例: consumer の Infrastructure) からも依存できる。
        .library(
            name: "StandardAppLogging",
            targets: ["StandardAppLogging"]
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
        ),
        .target(
            name: "StandardAppLogging",
            swiftSettings: [
                // consumer (swift-tools 6.0 / strict concurrency) と同じ前提で lib 自身も
                // 検査する。package 全体の tools bump は他 target / consumer に波及するため
                // target 限定で complete checking を有効化 (codex 設計review P2)。
                .enableExperimentalFeature("StrictConcurrency")
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
        .testTarget(
            name: "StandardAppLoggingTests",
            dependencies: ["StandardAppLogging"]
        )
    ]
)
