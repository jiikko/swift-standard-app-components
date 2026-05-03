// 最小サンプル: SettingsWindow + 外観切替 + 言語切替を採用したアプリの骨格。
// このファイルはビルド対象には入っていない（参照用）。
//
// 各アプリの SPM 依存に
//   .package(url: "git@github.com:jiikko/swift-standard-app-components.git", branch: "master")
// を追加し、target dependencies に "StandardAppComponents" を含めて使う。

import SwiftUI
import StandardAppComponents

@main
struct MinimalApp: App {
    init() {
        // 起動時にローカライズ漏れを検証 (lib 同梱キーが consumer の bundle で
        // 引けない状態なら fatalError で止める)
        StandardAppComponentsLocalization.validateRequiredKeys()
    }

    @AppStorage("appearanceMode")
    private var rawAppearanceMode: String = StandardAppearanceMode.system.rawValue

    private var appearanceMode: StandardAppearanceMode {
        StandardAppearanceMode(rawValue: rawAppearanceMode) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .applyAppAppearance(appearanceMode.preferredColorScheme)
        }

        Settings {
            SettingsWindow(
                general: GeneralTabContract(
                    appearance: { AppearanceSection(rawMode: $rawAppearanceMode) },
                    language: {
                        // LanguageSection は lib 提供。consumer は対応言語のリストを
                        // 渡すだけで System Default + Restart Now / Later フローを得る。
                        LanguageSection(supportedLanguages: [
                            .init(code: "en", displayName: "English"),
                            .init(code: "ja", displayName: "日本語")
                        ])
                        // onRestart はデフォルト `NSApp.terminate(nil)`。relaunch
                        // したい場合のみ closure を渡す。
                    }
                    // appSections は省略 (アプリ固有設定がない場合)
                ),
                width: 520,
                heights: [SettingsWindowConstants.generalTabId: 280]
            )
            .applyAppAppearance(appearanceMode.preferredColorScheme)
        }
    }
}

private struct ContentView: View {
    var body: some View {
        Text("Hello")
            .frame(minWidth: 320, minHeight: 200)
    }
}

// 各アプリが実装する外観セクション (lib 側には用意していないので consumer が実装する)
private struct AppearanceSection: View {
    @Binding var rawMode: String

    var body: some View {
        Picker("テーマ", selection: binding) {
            Text("システム").tag(StandardAppearanceMode.system)
            Text("ライト").tag(StandardAppearanceMode.light)
            Text("ダーク").tag(StandardAppearanceMode.dark)
        }
        .pickerStyle(.segmented)
    }

    private var binding: Binding<StandardAppearanceMode> {
        Binding(
            get: { StandardAppearanceMode(rawValue: rawMode) ?? .system },
            set: { rawMode = $0.rawValue }
        )
    }
}

// 渡し忘れた場合のコンパイルエラー例（コメントアウトを外すとコンパイルエラー）:
//
// SettingsWindow(
//     general: GeneralTabContract(
//         appearance: { AppearanceSection(rawMode: $rawAppearanceMode) }
//         // language を渡し忘れる -> Missing argument for parameter 'language' in call
//     )
// )
